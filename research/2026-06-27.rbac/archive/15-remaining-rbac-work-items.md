# Remaining RBAC / blast-radius work items

This is a concise outline of what we can still address after the research and decision to abandon the in-process `pre_tool_call` approach.

---

## 1. Implement the ContextForge MCP gateway

- Decision made: use **ContextForge** as the MCP gateway, not a custom proxy.
- Tasks: deploy ContextForge as a single container with SQLite, register an MCP server, define tool-level allow/deny rules using native RBAC, enable auth/rate-limit/audit logging, and document the single-host deployment.
- Fallbacks: **Kong Gateway** if you already have a Kong Enterprise/Konnect license; **Pomerium** when identity-aware access control is the primary concern.

## 2. Runtime integrity hardening (decided)

- **No read-only mounts** for `~/.hermes/plugins/` and `~/.hermes/skills/`.
- **Disable `execute_code` entirely.** Replaced by **`vndee/llm-sandbox`** MCP server.
- **Disable `terminal` entirely.** Replaced by the same **`vndee/llm-sandbox`** MCP server (one server for both code and shell).
- Plugin/skill integrity relies on trusted sources and periodic audit, not filesystem immutability.
- See [24-mcp-server-selection.md](./24-mcp-server-selection.md) for the full MCP server selection matrix.

## 3. Policy engine choice (done)

- **Selected:** ContextForge native RBAC/ABAC.
- **OPA and Casbin are explicitly out of scope** for this project.
- If ContextForge native RBAC/ABAC proves insufficient, evaluate ContextForge's Cedar plugin before considering anything else.

## 4. Human-in-the-loop

- Design an async approval queue for high-risk actions.
- Define risk scoring: recipient domain, file path, operation type, OAuth scope, time of day.
- Choose the out-of-band channel: Telegram/Discord/Slack DM or a local web dashboard.

## 5. Credential scoping (decided: no credential broker)

- **No credential broker is used.** ClawShell and Infisical Agent Vault are out of scope.
- Credentials live in the Hermes/MCP-server environment as **tightly scoped static tokens**:
  - LLM provider keys with usage/budget limits and provider-side rotation.
  - Fine-grained GitHub PATs with the minimum required repo permissions.
  - Send-restricted SMTP app passwords or OAuth-scoped mail credentials.
  - Per-MCP-server credentials, not shared across servers.
- **Compensating controls:** Pipelock DLP/egress allowlisting, ContextForge tool-level policy, and provider-side scoping.
- **Accepted residual risk:** a compromised agent still holds real credentials and could misuse them on allowed endpoints. This risk is explicitly documented in `21-settled-decisions.md` §9.

## 6. Observability

- Write a decision-log schema for the policy proxy (tool call, policy result, matched rule, timestamp, hash of args).
- Forward logs to the same pipeline used by Pipelock and rsyslog.

## 7. Guide updates

- Add a "Runtime integrity" section to the hardening guide.
- Document the email/MCP gateway patterns.
- Update the access-control section to explain why `pre_tool_call` is not a boundary.
- Add a verification checklist for each layer.
