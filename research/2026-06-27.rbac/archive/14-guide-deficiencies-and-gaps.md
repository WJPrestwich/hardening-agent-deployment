# Known guide deficiencies: runtime integrity and policy enforcement

This page captures current (and hopefully temporary) gaps in the hardening guide that weaken RBAC, blast-radius control, and runtime integrity. These are not criticisms of the existing work; they are the next items to assess and address.

---

## Runtime integrity

| # | Deficiency                                                  | Why it matters                                                                                                                                                                              | Possible direction                                                                                            |
|---|-------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| 1 | No protection against in-process monkey-patching.           | Hermes, plugins, skills, and `execute_code` all run in one Python interpreter. A compromised agent can patch `sys.modules`, `registry.dispatch`, `invoke_hook`, or the guard module itself. | Move critical enforcement out of process; restrict `execute_code`/`terminal`; research read-only code mounts. |
| 2 | `~/.hermes/plugins/` and `~/.hermes/skills/` are writable.  | A malicious skill or plugin can install/overwrite code, shadow built-in tools with `override=True`, or remove the guard.                                                                    | Separate writable state from code; install plugins/skills as root and mount them read-only.                   |
| 3 | No plugin or skill signing/verification.                    | The guide trusts code placed in `~/.hermes/plugins/` and `~/.hermes/skills/`.                                                                                                               | Research whether Hermes supports signatures; if not, add a host-side verification step before installing.     |
| 4 | `execute_code` runs arbitrary Python in the Hermes runtime. | Even with the sandbox RPC, the child process can monkey-patch or call tools directly (see issue #4146).                                                                                     | Disable `execute_code` for unattended runs, or force it into an isolated container/remote backend.            |
| 5 | `terminal` defaults to `local` backend.                     | Shell commands run as the Hermes user inside the writable state environment.                                                                                                                | Default to `docker` or `ssh` terminal backend in high-security deployments.                                   |

---

## Tool-call and MCP governance

| #  | Deficiency                                          | Why it matters                                                                                                                                         | Possible direction                                                                            |
|----|-----------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|
| 6  | No fine-grained, argument-level tool authorization. | `disabled_toolsets` and MCP `include`/`exclude` are coarse. The agent can call `send_email` to any recipient or `write_file` to any path it can reach. | Build an out-of-process `policy proxy` that authorizes every tool call and MCP request.       |
| 7  | `pre_tool_call` is not a security boundary.         | It is in-process, fail-open on crashes, and bypassable in worker/agent-loop paths.                                                                     | Do not use it for enforcement; use it only for logging/telemetry.                             |
| 8  | MCP servers expand the trust boundary unchecked.    | A compromised MCP server can inject instructions and the agent will execute them as tools.                                                             | Per-server allowlists, credential scoping, and proxying MCP traffic through the policy proxy. |
| 9  | No per-tool or per-MCP-server approval queue.       | High-risk actions rely on synchronous prompts or `approvals.mode`, not a durable queue.                                                                | Design an async HITL approval queue for email send, destructive commands, and MCP writes.     |
| 10 | Tool-name prefixes are unstable.                    | MCP tools have used `mcp_<server>_<tool>` and `mcp__<server>__<tool>` in different versions.                                                           | Policies should match on stable server/action metadata, not string prefixes.                  |

---

## Email and exfiltration

| #  | Deficiency                                   | Why it matters                                                          | Possible direction                                                                                  |
|----|----------------------------------------------|-------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| 11 | No per-recipient or per-domain email policy. | OAuth scopes are coarse; a `send` scope allows any recipient.           | Add an email egress gateway that enforces recipient allowlists, attachment limits, and send quotas. |
| 12 | No DLP on SMTP/IMAP traffic.                 | Pipelock handles HTTP egress, but native email protocols may bypass it. | Route email through the gateway and scan content/attachments before delivery.                       |

---

## Filesystem and credentials

| #  | Deficiency                                                         | Why it matters                                              | Possible direction                                                                    |
|----|--------------------------------------------------------------------|-------------------------------------------------------------|---------------------------------------------------------------------------------------|
| 13 | No workspace jail beyond Docker bind mounts.                       | The agent can write anywhere the container user has access. | Research Landlock/ACL/FUSE overlays to restrict file access to an explicit workspace. |
| 14 | No credential broker. LLM-provider, GitHub, SMTP, browser, filesystem, and MCP-server credentials live in the Hermes/MCP-server environment as scoped static tokens. | This simplifies the architecture but means a compromised agent already has real credentials in memory. Exfiltration is still blocked by Pipelock DLP/egress allowlists, and semantic misuse is partially mitigated by ContextForge tool-level policy, but the agent can still misuse credentials on allowed endpoints. | Compensate with tightly scoped tokens (fine-grained PATs, send-restricted SMTP, per-MCP-server keys), provider-side rotation, Pipelock DLP/egress controls, ContextForge per-tool policy, and deception controls (canary tokens). Document the accepted residual risk. |
| 15 | No canary files or deception controls.                             | We cannot detect unauthorized reads or reconnaissance.      | Add canary tokens in the workspace and fake secrets to detect misuse.                 |

---

## Observability and limits

| #  | Deficiency                                           | Why it matters                                                            | Possible direction                                                              |
|----|------------------------------------------------------|---------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| 16 | No per-tool rate limits or daily quotas.             | A runaway or compromised agent can send thousands of emails or API calls. | Add rate limiting in the policy proxy and per-tool budgets.                     |
| 17 | No tamper-evident audit log for tool-call decisions. | We cannot prove after an incident what was allowed or denied.             | Write signed/decision logs for guard decisions, Tirith verdicts, and approvals. |

---

## See also

- [13-pre-tool-call-poor-fit.md](./13-pre-tool-call-poor-fit.md) — why in-process hooks fail as a boundary.
- [15-remaining-rbac-work-items.md](./15-remaining-rbac-work-items.md) — what to do next.
