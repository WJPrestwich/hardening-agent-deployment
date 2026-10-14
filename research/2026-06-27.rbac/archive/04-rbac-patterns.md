# D. Existing agent RBAC / authorization patterns

- Common pattern: keep the exposed tool set small, then enforce policy
  deterministically in middleware or a gateway before executing tools.
- **OpenAI**: project-scoped keys, function/tool search, strict schema mode,
  and reverse-proxy/gateway patterns for centralized access control.
- **Anthropic Agent SDK**: `PreToolUse` / `PostToolUse` hooks and a permission
  manager support allow/deny/modify decisions.
- **LangChain / LangGraph**: `wrap_tool_call` middleware and
  `before/after_node_execution` hooks can call an external PDP; LangSmith adds
  ABAC.
- **Policy engines**:
  - **OPA/Rego**: flexible centralized PDP; good for custom rules, needs
    caching for high QPS.
  - **Cedar** (AWS AgentCore pattern): deny-by-default gateway policy,
    partial evaluation to omit impossible tools, Lambda interceptors for
    tenant context.
  - **SpiceDB** (ReBAC): fast relationship-based checks, integrates with
    LangChain for document/tool authorization.
- **Open-source guardrails/proxies**: OpenGuardrails, Gravitee AI Agent Mesh,
  Forge (TensorBlock), AgentGateway, Data443 proxy architecture.

For a detailed explanation of PDPs, policy-engine mechanics, and the
open-source landscape, see
[10-policy-engines-deep-dive.md](./10-policy-engines-deep-dive.md).

## Sources

- OpenAI function-calling and RBAC docs
- Anthropic Agent SDK guide
- LangChain middleware docs
- AWS/AgentCore Cedar blogs
- AuthZed SpiceDB LangChain integration
- Natoma OPA-vs-Cedar comparison
- OpenGuardrails, Gravitee, Forge, AgentGateway, Data443 project docs
