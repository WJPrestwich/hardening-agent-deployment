# Hermes tool exposure: a fundamentally risky design

This page assesses what Hermes brings to the table from a security perspective. The short answer is: **a large, in-process, privileged tool surface that is hard to harden without disabling most of its native capabilities.**

This is not a critique of Hermes as a product; it is an honest look at why the current architecture makes blast-radius reduction difficult, and what that implies for the policy proxy.

---

## The core problem

Hermes treats **tools as first-class, in-process extensions of the agent.** Native tools run inside the same Python interpreter as the agent loop, skills, plugins, and configuration. There is no architectural separation between:

- the model deciding to act,
- the tool dispatcher,
- the tool handler, and
- the host resources the tool touches.

In a safer design, these would be separated by process boundaries, capability sandboxes, and explicit authorization. Hermes does not do that by default.

---

## Evidence: the native tool surface

Hermes ships with roughly **71 native tools** across ~29 toolsets ([Built-in Tools Reference](https://hermes-agent.nousresearch.com/docs/reference/tools-reference)):

| Capability class         | Representative tools                                                            |
|--------------------------|---------------------------------------------------------------------------------|
| Arbitrary code execution | `execute_code`                                                                  |
| Shell / process control  | `terminal`, `process`                                                           |
| Filesystem               | `read_file`, `write_file`, `patch`, `search_files`                              |
| Web / browser            | `web_search`, `web_extract`, `browser_navigate`, `browser_click`, `browser_cdp` |
| Messaging                | `send_message`, `discord`, `discord_admin`                                      |
| Home automation          | `ha_call_service`, `ha_list_entities`                                           |
| Scheduling               | `cronjob`                                                                       |
| Subagents                | `delegate_task`                                                                 |
| Skills / memory          | `skill_manage`, `skill_view`, `memory`, `session_search`                        |
| Media generation         | `image_generate`, `video_generate`, `text_to_speech`                            |
| Third-party integrations | Spotify, Feishu, Yuanbao, kanban                                                |

Many of these tools are **high-privilege by default** and operate directly on the host or on external services.

---

## Specific design flaws that create blast radius

### 1. Native tools run in-process

`execute_code`, `terminal`, `read_file`, `browser_navigate`, and `send_message` are not isolated behind a proxy or sandbox. They execute as the Hermes user inside the same container/state volume. A compromised agent can:

- Call any native tool directly, bypassing any in-process hook.
- Monkey-patch `sys.modules`, the tool registry, or the guard module itself.
- Use `execute_code` to run arbitrary Python that calls other tools.

This is why `pre_tool_call` cannot be a security boundary (see [13-pre-tool-call-poor-fit.md](./13-pre-tool-call-poor-fit.md)).

### 2. `execute_code` and `terminal` are universal bypasses

Even if every other tool is restricted, `execute_code` lets the agent run arbitrary Python, and `terminal` lets it run arbitrary shell commands. Either one can reimplement the rest of the tool surface:

```python
# execute_code can do anything
import subprocess, os, requests
subprocess.run(["rm", "-rf", "/workspace"])
```

Hermes' own docs describe `execute_code` as useful for "3+ tool calls with processing logic between them" — i.e., it is a first-class bypass around the normal tool-call boundary.

### 3. Skills and plugins extend the attack surface at runtime

Hermes loads skills from `~/.hermes/skills/` and plugins from `~/.hermes/plugins/`. In the hardened container, those directories are **writable** by the agent. A compromised agent can:

- Install a new skill that registers a malicious tool.
- Overwrite an existing skill with `override=True`.
- Add a plugin that shadows a built-in tool with a bypass wrapper.

There is no built-in signature verification or hash checking for skills or plugins by default.

### 4. The config is mutable by the agent

Hermes stores `config.yaml` in `~/.hermes/`. The hardened container mounts the config file read-only, but the rest of `~/.hermes/` is writable. A compromised agent can:

- Disable Tirith (`tirith_enabled: false`).
- Change `terminal.backend` back to `local`.
- Add excluded toolsets back into the active set.
- Rewrite `MEMORY.md`/`USER.md` to poison future sessions.

This is why the guide explicitly mounts `config.yaml` read-only from the host; without that, the agent can simply turn off its own guardrails.

### 5. MCP tools are not strongly isolated from native tools

Hermes exposes MCP-mediated tools with the same naming and dispatch path as native tools (`mcp_<server>_<tool>`). From the agent's perspective, an MCP tool and a native tool are equally callable. The only reliable difference is that an MCP proxy can intercept the MCP path — but the agent can still fall back to native equivalents (`terminal`, `write_file`, `web_search`) if those are not disabled.

### 6. The approval model is coarse or absent

Hermes does not have a native per-tool approval queue or argument-level policy engine. The existing controls are:

- `tools.include` / `tools.exclude` lists.
- `tirith_*` pattern-based command scanning.
- Optional first-invoke approval for MCP servers (issue #16462, not yet shipped).

None of these provide "allow `read_file` only under `/workspace`, deny all `send_message` except to example.com" semantics.

### 7. The tool naming is unstable

Hermes has used different separators for MCP tool names across versions. This makes it hard to write stable allow/deny policies and easy for a malicious skill to register a tool whose name looks like an MCP tool but is actually native.

---

## What a safer design would look like

A tool exposure model designed for security would:

1. **Run every tool out-of-process** in a sandbox with no access to the agent interpreter.
2. **Disable arbitrary code execution by default** or force it into a one-shot, isolated container.
3. **Sign and verify skills/plugins** before loading them.
4. **Separate config from state** and make policy immutable to the agent.
5. **Use a capability model** where the agent requests access to specific directories, hosts, and APIs, and the user or operator grants it.
6. **Log every tool call to tamper-evident storage outside the agent process.**

Hermes does not do these things today. That is why hardening it requires so much external compensating control.

---

## What this means for the policy proxy

The architecture of the policy proxy must accept that **Hermes itself is not a trustworthy execution boundary.** The design must therefore:

1. **Disable the dangerous native toolsets** rather than trying to restrict them in-process (see [17-hermes-native-tools-and-mcp-replacements.md](./17-hermes-native-tools-and-mcp-replacements.md)).
2. **Replace needed capabilities with MCP-wrapped equivalents** running outside the agent process.
3. **Route all MCP tool calls through ContextForge** (or another trusted proxy) for policy, auth, logging, and rate limiting.
4. **Keep the config read-only** and the state volume as small as possible.
5. **Add OS-level isolation** (Landlock/AppArmor, read-only rootfs, no network egress except through the proxy) for whatever native capabilities remain.
6. **Treat prompt/model guardrails** as only a first layer, not the primary enforcement (see [19-model-prompt-guardrails-deep-dive.md](./19-model-prompt-guardrails-deep-dive.md)).

---

## Bottom line

Hermes' main contribution to this project is **not** a rich set of safely exposed capabilities. It is a large, in-process, privileged tool surface that must be aggressively reduced before any MCP proxy or policy engine can become meaningful.

The hardening task is therefore less "add policy on top of Hermes" and more "remove or relocate most of Hermes' native power, then put a trusted proxy in front of the small set of capabilities that remain."

---

## Sources

- Hermes Agent docs: [Built-in Tools Reference](https://hermes-agent.nousresearch.com/docs/reference/tools-reference)
- Hermes Agent docs: [Toolsets Reference](https://hermes-agent.nousresearch.com/docs/reference/toolsets-reference)
- Hermes Agent docs: [Code Execution](https://hermes-agent.nousresearch.com/docs/user-guide/features/code-execution)
- Hermes Agent docs: [MCP Integration](https://hermes-agent.nousresearch.com/docs/user-guide/features/mcp)
- [13-pre-tool-call-poor-fit.md](./13-pre-tool-call-poor-fit.md)
- [14-guide-deficiencies-and-gaps.md](./14-guide-deficiencies-and-gaps.md)
- [17-hermes-native-tools-and-mcp-replacements.md](./17-hermes-native-tools-and-mcp-replacements.md)
