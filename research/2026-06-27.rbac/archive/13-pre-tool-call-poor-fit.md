# Why `pre_tool_call` is a poor security boundary

**Position:** Hermes' `pre_tool_call` hook should not be the enforcement point for a security-critical guard like the policy proxy. It is useful for logging, telemetry, and soft policy hints, but it is not a trust boundary.

---

## Why it looks attractive

The Hermes docs advertise `pre_tool_call` as firing "before any tool executes — built-in tools and plugin tools alike," with a return value of `{"action": "block", "message": str}` that vetoes the call. It also sees MCP tools because those are registered in the same tool registry. That makes it a natural place to drop a policy check.

The problem is that the hook runs **inside the same Python process as the agent**, and every other powerful Hermes feature runs there too. Any control that lives in-process can be bypassed by code that already has in-process execution.

---

## Why it is not a boundary

### 1. Same-process runtime manipulation

Hermes, its plugins, its skills, and the agent's own tools all share one Python interpreter. A compromised agent can:

- Monkey-patch `invoke_hook` or `registry.dispatch` to skip the guard.
- Replace the guard function object in the hook registry.
- Mutate `sys.modules` to shadow the guard module.
- Patch Casbin's `Enforcer.enforce` to always return `True`.

The `execute_code` tool gives the agent a first-class way to run arbitrary Python in this process. GitHub issue #41 describes `execute_code` as "unrestricted code execution" that bypasses terminal safety and approval systems. Issue #4146 showed that the `execute_code` sandbox exposed a `terminal()` RPC stub, allowing sandboxed Python to run arbitrary shell commands without dangerous-command approval.

A security control that can be disabled by the thing it is supposed to control is not a security control.

### 2. The hook is fail-open on errors

Hermes' hook documentation explicitly says:

> "If a callback crashes, it's logged and skipped. Other hooks and the agent continue normally."

That is the right behavior for a logging hook, but it is the wrong behavior for a guard. An attacker only needs to make the guard callback raise an exception — e.g., by passing an argument shape the policy builder cannot handle — and the tool runs.

### 3. The guard's files live in writable `~/.hermes/`

Our hardened container mounts the root filesystem read-only, but it mounts `~/.hermes` as a writable named volume (`hermes-state`). Only `config.yaml` is bind-mounted read-only on top. The plugin directory `~/.hermes/plugins/hermes-casbin-guard/` and any policy directory under `~/.hermes/` are therefore writable by the agent user.

A compromised agent can delete, replace, or corrupt the guard plugin and its policies. It does not need to exploit a bug in the guard; it can simply remove it.

### 4. Plugins can shadow tools and other hooks

Hermes allows a plugin to replace a built-in tool by registering the same name with `override=True`. Plugins also load from the writable `~/.hermes/plugins/` directory. A malicious plugin (or a malicious skill that installs a plugin) can:

- Replace `terminal` or `execute_code` with a wrapper that bypasses the guard.
- Register another `pre_tool_call` hook that runs before or instead of the guard.
- Disable the guard plugin by dropping a no-op plugin with the same name.

### 5. Worker and agent-loop paths bypass the registry hook

Hermes dispatches some tools (`todo`, `memory`, `session_search`, `delegate_task`) through `run_agent.py` before they reach the central registry where `pre_tool_call` is invoked. A recent change extended blocking to those paths, but the architecture is not uniform.

More importantly, GitHub issue #25204 reports that `pre_tool_call` shell hooks do **not fire reliably** from the kanban-worker `chat -q` context because the worker spawn lifecycle bypasses hook dispatch. If a security-relevant tool call can take a code path that skips the hook, the hook cannot be the authoritative policy point.

### 6. Tool-name churn breaks policies

Hermes has used different separators for MCP tool names across versions: `mcp_<server>_<tool>` and `mcp__<server>__<tool>`. A policy that matches one prefix silently misses tools using the other. Because the naming is not a stable contract, regex-based policy rules are fragile.

### 7. `execute_code` and `terminal` are bypasses even when the hook works

Even if `pre_tool_call` correctly blocks a direct `send_email` call, the agent can call `execute_code` or `terminal` and, from inside the allowed call, perform the same action directly. The hook authorizes the *tool call*; it does not control the *runtime behavior* of the tool.

---

## What this means for the policy proxy

- **Do not implement the policy proxy as a Hermes plugin using `pre_tool_call`.** It would give a false sense of security while remaining trivially bypassable.
- **Use `pre_tool_call` only for non-binding purposes:** logging, telemetry, cost attribution, or user-facing warnings.
- **If we need policy enforcement, move it out of process.** A separate the policy proxy process or sidecar should sit between the agent and the resources it wants to protect (MCP servers, email gateways, filesystem operations, etc.). The agent should not be able to reach those resources except through the guard, and the guard should run under a different user or in a separate container so the agent cannot patch it.

---

## But isn't Tirith also in-process?

Yes, and the same runtime-integrity caveats apply to Tirith in theory. The difference is scope and integration:

- Tirith is a single-purpose command scanner invoked by Hermes core, not a user-installable plugin.
- It is configured fail-closed (`tirith_fail_open: false`).
- It scans command *strings*, which are easier to inspect than arbitrary tool arguments.

Tirith is still not a sandbox, but it is a more defensible single layer than a user plugin that tries to authorize every tool call. The moment we want fine-grained, argument-level policy enforcement, we need an out-of-process boundary.

---

## Conclusion

`pre_tool_call` is a lifecycle hook, not a security boundary. Relying on it for the policy proxy would be security theater. We should abandon the in-process plugin design and build it as an external policy proxy.

---

## Sources

- Hermes Agent docs: "Event Hooks" (hook crash behavior and `pre_tool_call` veto)
- Hermes Agent docs: "Tools Runtime" (dispatch flow and agent-loop tools)
- Hermes Agent docs: "Code Execution" (`execute_code` runs arbitrary Python)
- Hermes Agent docs: "Build a Hermes Plugin" (`override=True` and plugin loading from `~/.hermes/plugins/`)
- GitHub issue #41: "Unrestricted Code Execution in `execute_code` Tool (Sandbox Bypass)"
- GitHub issue #4146: "Sandbox code execution bypasses dangerous command approval via `terminal` tool"
- GitHub issue #7072: "Skills Guard Complete Bypass via Dynamic Import and String Construction"
- GitHub issue #25204: "`pre_tool_call` shell hooks do not fire reliably in kanban-worker `chat -q` context"
- `hermes-agent/container-flags-explained.md` (`~/.hermes` writable, `config.yaml` read-only)
- `hermes-agent/assets/hermes-run` (Docker volume mount for `~/.hermes`)
