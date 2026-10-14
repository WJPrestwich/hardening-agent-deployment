# Hermes tool-call authorization with Casbin

> **Archived — superseded.** This design was abandoned when we decided (see `21-settled-decisions.md` §4 and §8) that `pre_tool_call` is not a security boundary and that Casbin/OPA are out of scope. ContextForge's native RBAC/ABAC is the policy layer. The page is retained for historical reference only.

This page describes how to layer **Casbin** onto Hermes Agent so that every native tool call and every MCP-mediated tool call is authorized before it runs.

**Key boundary:** we continue to use Hermes' built-in **Tirith** for command-scanning (shell commands), and we use **Casbin** for tool-call authorization. Tirith decides whether a command string looks dangerous; Casbin decides whether this agent, in this context, is allowed to invoke this tool with these arguments at all.

---

## Why Casbin fits here

Hermes already has coarse controls:

- `agent.disabled_toolsets` / `enabled_toolsets` hide whole tool categories.
- MCP server configs support `tools.include` / `tools.exclude` to allow/block entire MCP tools.
- `approvals.mode` prompts the user before flagged commands.

What is missing is **argument-level, policy-driven authorization**: e.g., "`send_email` is allowed, but only to `example.com` domains" or "`filesystem` `write` is allowed only under `/workspace`" or "`mcp_github__create_issue` is allowed, but `mcp_github__delete_repo` is not."

Casbin fills that gap without adding a database or a sidecar.

---

## Hermes tool-call interception point

Hermes exposes a `pre_tool_call` hook that fires immediately before every tool execution. According to the Hermes docs and runtime source:

> `pre_tool_call` fires before any tool executes and can return `{"action": "block", "message": str}` to veto the call.

Dispatch flow:

```
Model response with tool_call
        │
        ▼
run_agent.py agent loop
        │
        ▼
model_tools.handle_function_call(name, args, task_id, user_task)
        │
        ▼
invoke_hook("pre_tool_call", tool_name, args, task_id, kwargs)
        │
        ▼
registry.dispatch(name, args, kwargs)   ← only if hook did NOT block
        │
        ▼
invoke_hook("post_tool_call", ...)
```

Source: Hermes Agent docs — "Tools Runtime" and "Event Hooks".

This hook sees **both native tools and MCP tools** because MCP tools are registered into the same tool registry at startup. MCP tool names are prefixed so the server is identifiable, e.g. `mcp__github__create_issue`.

---

## Plugin integration design

A minimal Hermes plugin registers a `pre_tool_call` callback that consults Casbin.

### Request shape passed to Casbin

```python
{
  "subject": {
    "agent_id": "hermes-001",
    "user_id": "alice",
    "profile": "default"
  },
  "action": "create_issue",          # un-prefixed tool action
  "resource": {
    "tool_name": "mcp__github__create_issue",  # full Hermes tool name
    "server": "github",                        # empty for native tools
    "args": { "owner": "DaftValac", "repo": "hardening-agents" }
  },
  "context": {
    "risk_score": 0.2,
    "source": "cli"                # cli, telegram, cron, etc.
  }
}
```

The Casbin request can be flattened to a tuple for `Enforce()`:

```python
e.enforce(
    request["subject"]["user_id"],
    request["resource"]["tool_name"],
    request["action"],
    json.dumps(request["resource"]["args"])
)
```

### Example plugin skeleton

```python
# ~/.hermes/plugins/hermes-casbin-guard/guard.py
import json
import os
import casbin

POLICY_DIR = os.path.expanduser("~/.hermes/casbin-guard")

_policy = None

def _load_policy():
    global _policy
    if _policy is None:
        _policy = casbin.Enforcer(
            os.path.join(POLICY_DIR, "model.conf"),
            os.path.join(POLICY_DIR, "policy.csv"),
        )
    return _policy


def _build_request(tool_name: str, args: dict, task_id: str, kwargs: dict):
    # Split mcp__github__create_issue (or mcp_github_create_issue) into
    # server + action. Hermes has used both single- and double-underscore
    # separators for MCP tools, so handle both.
    if "__" in tool_name:
        parts = tool_name.split("__", 2)
    else:
        parts = tool_name.split("_", 2)
    if len(parts) == 3 and parts[0] == "mcp":
        server, action = parts[1], parts[2]
    else:
        server, action = "", tool_name

    return {
        "sub": kwargs.get("user_id", "unknown"),
        "tool": tool_name,
        "server": server,
        "action": action,
        "args": json.dumps(args, sort_keys=True),
    }


def guard(tool_name: str, args: dict, task_id: str, kwargs: dict):
    try:
        e = _load_policy()
        r = _build_request(tool_name, args, task_id, kwargs)
        allowed = e.enforce(r["sub"], r["tool"], r["action"], r["args"])
    except Exception as exc:
        # Hermes skips a crashing hook and allows the tool. Fail closed.
        _log_decision({"tool": tool_name, "args": args}, allowed=False,
                      note=f"guard_error: {exc}")
        return {
            "action": "block",
            "message": f"hermes-casbin-guard could not evaluate {tool_name}: {exc}",
        }

    _log_decision(r, allowed=allowed)

    if not allowed:
        return {
            "action": "block",
            "message": f"Policy denied {tool_name} with args {args}",
        }

    return None  # allow Hermes to continue


def register(ctx):
    ctx.register_hook("pre_tool_call", guard)
```

### Example Casbin model

```ini
[request_definition]
r = sub, tool, action, args

[policy_definition]
p = sub, tool, action, pattern, eft

[policy_effect]
e = some(where (p.eft == allow)) && !some(where (p.eft == deny))

[matchers]
m = (r.sub == p.sub || p.sub == "*") && \
    (r.tool == p.tool || p.tool == "*") && \
    (r.action == p.action || p.action == "*") && \
    (p.pattern == "*" || regexMatch(r.args, p.pattern))
```

### Example policy

```csv
# Native filesystem tool: allow reads anywhere, allow writes only under /workspace
p, *, filesystem, read, *, allow
p, *, filesystem, write, "/workspace/.*", allow
p, *, filesystem, write, ".*", deny

# Email tool: allow send only to example.com and its subdomains
p, *, email, send, ".*@([a-zA-Z0-9_-]+\\.)?example\\.com.*", allow
p, *, email, send, ".*", deny

# MCP GitHub: allow read/list, deny destructive operations
p, *, mcp__github__*, *, *, allow
p, *, mcp__github__delete_repo, *, *, deny
p, *, mcp__github__delete_issue, *, *, deny

# Default deny for anything not explicitly allowed
p, *, *, *, *, deny
```

---

## How this covers MCP tools

Hermes' native MCP client registers each MCP server as a toolset. By the time the agent calls a tool, it has a Hermes-facing name like `mcp__github__create_issue`. Casbin policies can match:

- The whole prefixed name (`mcp__github__create_issue`).
- A wildcard over a server's tools (`mcp__github__*`).
- The JSON-serialized arguments with regex patterns.

Hermes' own `tools.include` / `tools.exclude` are still useful as a first-level filter to keep the tool surface small and reduce token usage, but Casbin adds the fine-grained, auditable authorization layer.

---

## Where Tirith still fits

Tirith scans shell commands before they run. Casbin should **not** try to reimplement Tirith's pattern/semantic analysis. The split is:

| Concern                                                             | Enforcer   |
|---------------------------------------------------------------------|------------|
| Is this shell command string destructive / suspicious?              | **Tirith** |
| Is this agent allowed to invoke `terminal` with these args?         | **Casbin** |
| Is this agent allowed to call `mcp__email__send` to this recipient? | **Casbin** |
| Is this agent allowed to write to this file path?                   | **Casbin** |

If a tool call reaches a shell command, both checks fire: Casbin at the tool call boundary, Tirith at the command boundary.

---

## What `pre_tool_call` cannot guarantee

`pre_tool_call` is a **policy-enforcement helper**, not a security boundary. A compromised or sufficiently clever agent can bypass or neutralize it in several ways:

1. **Tampering with the guard itself.** If the Hermes process can write to `~/.hermes/plugins/hermes-casbin-guard/` or to the policy directory, it can delete, replace, or corrupt the plugin. Hermes does not cryptographically sign plugins by default.
2. **In-process runtime manipulation.** The hook runs inside the same Python process as the agent. Code executed via `execute_code`, `terminal`, or a malicious skill can monkey-patch `invoke_hook`, `registry.dispatch`, or the guard module itself.
3. **Hook crash bypass.** Hermes' hook docs state: "If a callback crashes, it's logged and skipped. Other hooks and the agent continue normally." The guard must therefore never raise on unexpected input; it should return a block on any internal error (fail-closed).
4. **Agent-loop and worker code paths.** Some tools (`todo`, `memory`, `session_search`, `delegate_task`) are intercepted by `run_agent.py` before registry dispatch. A recent change extended `pre_tool_call` blocking to those paths, but issue #25204 reports that in kanban-worker `chat -q` contexts the hook does not fire reliably because the worker spawn lifecycle bypasses hook dispatch.
5. **Direct side effects inside an allowed tool.** Once `execute_code`, `terminal`, or `browser_navigate` is allowed, the code it runs can open sockets, write files, or call APIs directly. `pre_tool_call` only vets the *call*, not the *runtime behavior* of the tool.
6. **Subagent delegation.** A `delegate_task` call that starts a subagent may not load the same plugin set, depending on how the subagent is configured.
7. **Tool-name churn.** MCP tool prefixes have varied between Hermes versions (`mcp_<server>_<tool>` vs `mcp__<server>__<tool>`). A policy that matches one prefix silently misses the other.

Implications:

- Treat this design as an **auditable guardrail**, not a sandbox.
- Pair it with the existing hardening layers: read-only plugin/policy mounts, container MAC (AppArmor/SELinux/Landlock), Pipelock egress/DLP, Tirith command scanning, non-root execution, and short-lived credentials.
- If you need a stronger guarantee, move the guard **out of process**: run the policy proxy as a separate user or sidecar that Hermes talks to over a Unix socket, and make the real MCP servers and privileged tools unreachable except through that guard. That design is more tamper-resistant but also more intrusive.

---

## Audit and observability

Every Casbin decision should be logged with:

- `decision_id` (UUID)
- `timestamp`
- `tool_name`
- `args` (or a hash of sensitive args)
- `subject`
- `decision` (`allow` / `deny`)
- `policy_line_matched`

For consistency with the rest of the stack, write these logs to `/var/log/hermes-policy/decisions.log` and forward them through rsyslog if the host already uses the Pipelock logging pipeline.

---

## Open questions / next steps

1. **Plugin packaging**: decide whether `hermes-casbin-guard` is a pip package with an entry point or a directory copied into `~/.hermes/plugins/`.
2. **Policy reload**: implement a file watcher or SIGHUP handler so policy changes take effect without restarting Hermes.
3. **Human-in-the-loop**: for high-risk tool calls, have the hook return a block with a message that prompts the user, or queue the call for async approval.
4. **Obligations**: extend the model so Casbin can return obligations such as `require_approval`, `rate_limit`, or `log_only`.
5. **Migration path**: keep the Casbin interface small so it can later be swapped for an OPA sidecar if policies outgrow Casbin.

---

## Sources

- Hermes Agent docs: "Event Hooks" (`pre_tool_call` signature, veto, and crash-behavior)
- Hermes Agent docs: "Tools Runtime" (dispatch flow and agent-loop tools)
- Hermes Agent docs: "MCP" (per-server `tools.include` / `tools.exclude`)
- Hermes Agent docs: "Security" (Tirith and `approvals.mode`)
- Hermes Agent docs: "Built-in Tools Reference" (MCP tool prefixes)
- GitHub issue #25204: `pre_tool_call` shell hooks not firing reliably in kanban-worker `chat -q` context
- Casbin docs: PERM metamodel, ABAC, `regexMatch`, custom functions
