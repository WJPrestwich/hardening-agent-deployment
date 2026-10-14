# MCP proxy/gateway comparison matrix for Hermes

This page compares the most promising **widely-used, trusted** open-source MCP proxies and gateways against the requirements of a single-host Hermes deployment.

Scores are relative to Hermes' needs, not general quality. Last updated 2026-06-28.

---

## Evaluation criteria

| Criterion                       | Why it matters for Hermes                                                                     |
|---------------------------------|-----------------------------------------------------------------------------------------------|
| **Single-host friendly**        | The hardened Hermes guide targets one Ubuntu box, not Kubernetes.                             |
| **Transparent MCP proxy**       | Hermes must continue to use its existing MCP client (stdio/HTTP) with minimal config changes. |
| **Tool-level policy**           | Must allow/deny/ask per MCP tool name and inspect arguments.                                  |
| **Human-in-the-loop (HITL)**    | Optional approval queue for risky operations.                                                 |
| **Audit log**                   | Independent, tamper-evident record of tool calls for replay and incident response.            |
| **Policy engine**               | Support for at least one expressive rule engine (YAML, CEL, Cedar, OPA, Casbin).              |
| **Native tool handling**        | Whether the project acknowledges and helps mitigate in-process native tools.                  |
| **Hermes integration friction** | Estimated effort to wire into the hardened Hermes container.                                  |
| **Community / maturity**        | Stars, release cadence, documentation, and likely long-term support.                          |

---

## Candidate comparison

|                                 | **ContextForge**                                                                  | **Kong Gateway**                                                                            | **Pomerium**                                                                                      | **agentgateway**                                                              | **Bifrost**                                                                                   |
|---------------------------------|-----------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------|------ -----------------------------------------------------------------------------------------|
| **Repo**                        | `IBM/mcp-context-forge`                                                           | `kong/kong`                                                                                 | `pomerium/pomerium`                                                                               | `agentgateway/agentgateway`                                                   | `maximhq/bifrost`                                                                             |
| **Stars / forks**               | 3,974 / 725                                                                       | 43,686 / 5,160                                                                              | 4,872 / 339                                                                                       | 3,552 / 597                                                                   | 6,090 / 815                                                                                   |
| **Language / runtime**          | Python 3.11+ / Rust / Docker                                                      | Lua/Go (Kong)                                                                               | Go                                                                                                | Rust / Go                                                                     | Go                                                                                            |
| **License**                     | Apache 2.0                                                                        | Apache 2.0 core                                                                             | Apache 2.0                                                                                        | Apache 2.0                                                                    | Apache 2.0                                                                                    |
| **Single-host friendly**        | **Good** — PyPI (`uvx`) or single Docker container with SQLite                    | **Good** — Docker quickstart; heavier if you do not already run Kong                        | **Good** — single Go binary or Docker; well-documented standalone mode                            | **Fair** — standalone binary works, but docs and features assume Kubernetes   | **Fair** — Docker/`npx` quickstart, but enterprise/MCP features are newer                     |
| **Transparent MCP proxy**       | **Yes** — exposes virtual MCP servers via HTTP/SSE/stdio wrapper                  | **Yes** — AI MCP Proxy plugin bridges MCP↔HTTP; can proxy or convert REST APIs to MCP tools | **Yes** — identity-aware proxy for MCP servers; routes/auth, but does not deeply parse tool calls | **Yes** — MCP gateway with stdio/HTTP/SSE/streamable-HTTP support             | **Yes** — MCP gateway mode exists                                                             |
| **Tool-level policy**           | **Yes** — Cedar / OPA / native RBAC + 35+ security plugins                        | **Yes** — Kong plugins + MCP Tool ACLs; policy at route/plugin layer                        | **Partial** — identity/route/session-level authZ; not fine-grained MCP tool-name inspection       | **Yes** — CEL-based RBAC + guardrails                                         | **Partial** — governance plugins, virtual keys, budget controls; not per-tool semantic policy |
| **HITL approval**               | **Partial** — Admin UI and policy decisions; interactive approval less emphasized | **No** — not a HITL system; pure gateway                                                    | **No** — zero-trust access, not per-call approval                                                 | **Partial** — policy-driven UI for observability, not a native approval queue | **No** — designed for programmatic governance                                                 |
| **Audit log**                   | **Yes** — structured logs, OpenTelemetry, request logging                         | **Yes** — Kong logging/observability plugins, Prometheus MCP metrics                        | **Yes** — centralized audit of access decisions                                                   | **Yes** — OpenTelemetry metrics/logs/tracing                                  | **Yes** — request logging, Prometheus, tracing                                                |
| **Policy engine**               | Cedar, OPA, native RBAC (all open-source)                                         | Kong plugin ecosystem + OPA plugin (enterprise tier)                                        | Pomerium policy language (identity/context)                                                       | CEL RBAC                                                                      | Custom governance plugins                                                                     |
| **Native tool handling**        | No native Hermes integration; focuses on proxying MCP/A2A/REST                    | No native tool handling                                                                     | No native tool handling                                                                           | No native tool handling                                                       | No native tool handling                                                                       |
| **Hermes integration friction** | **Medium** — run gateway, register servers, create virtual server, use wrapper    | **Medium** — add MCP plugin and route config; learning curve if new to Kong                 | **Medium–Low** — place in front of HTTP MCP servers; stdio servers need an HTTP bridge            | **Medium** — configure gateway and routes; more moving parts                  | **Medium** — configure providers, MCP tools, governance rules                                 |
| **Maturity / community**        | Large IBM-backed project; many issues/PRs; broad scope; strong docs               | De-facto open-source API gateway; huge ecosystem; enterprise track record                   | Mature identity-aware proxy; active community; 1B+ Docker pulls                                   | Linux Foundation project; active meetings; K8s-oriented                       | Well-established AI gateway; large community; MCP features still maturing                     |
| **Best fit for Hermes**         | **Primary recommendation: open-source, purpose-built MCP gateway**                | **Fallback: only if you already have a Kong Enterprise/Konnect license**                    | **Identity/access control layer for HTTP MCP servers**                                            | **Enterprise-style governance if K8s is acceptable**                          | **LLM-provider governance (budgets, virtual keys, failover) alongside tools**                 |

---

## Detailed notes

### ContextForge

- **Most purpose-built for MCP governance.** It federates MCP, A2A, REST, and gRPC behind a unified endpoint.
- **Policy-engine choice:** Cedar, OPA, or native RBAC out of the box.
- Virtual-server model lets you compose tools from multiple MCP servers and expose them as one server to Hermes.
- Strong observability (OTel, Phoenix/Jaeger) and a web admin UI.
- Single-container SQLite mode is viable for one host.
- **Concerns:** larger surface area; more initial configuration; Python/Rust stack may be heavier than needed; HITL approval is not a headline feature.

### Kong Gateway

- **Most mature and widely deployed.** If the infrastructure already uses Kong, MCP governance becomes just another plugin.
- AI MCP Proxy plugin can proxy existing MCP servers or convert REST APIs into MCP tools.
- MCP Tool ACLs provide fine-grained authorization.
- **Concerns:** general-purpose API gateway, not an MCP-native product; MCP plugin requires Kong Gateway 3.12+; no built-in HITL approval queue.

### Pomerium

- **Best at identity-aware access control.** Authenticates users/agents via SSO and injects short-lived signed assertions.
- Supports MCP servers, including upstream OAuth2 flows (e.g., GitHub, Notion).
- **Concerns:** enforcement is at session/route/identity level, not deep inspection of individual MCP tool names or arguments; less suited to argument-level policies like "allow `read_file` only under `/workspace`".

### agentgateway

- Linux Foundation project with a clear governance story.
- Supports MCP, A2A, and LLM routing in one proxy.
- CEL-based RBAC is expressive and fits Casbin-style small rule sets.
- **Concerns:** documentation and quickstart lean Kubernetes; standalone mode exists but is less documented. HITL is not emphasized.

### Bifrost

- Mature, high-performance AI gateway with budget controls, virtual keys, and semantic caching.
- MCP support is documented but the project is primarily an LLM router, not a tool-authorization proxy.
- **Concerns:** no built-in per-tool human approval; governance is more about cost/rate limits than semantic tool policy.

---

## Preliminary recommendation

For the first policy-proxy prototype on a single host:

1. **Primary: ContextForge** — the best fit for an open-source hardening guide. It is Apache 2.0, purpose-built for MCP, runs as a single container with SQLite, and includes native RBAC/ABAC plus optional Cedar/OPA plugins. It also provides 35+ security plugins (PII filtering, schema guard, rate limiting) out of the box.
2. **Secondary: Kong Gateway** — still the most mature general-purpose API gateway, but only if you have a Kong Enterprise/Konnect license. Its AI MCP Proxy and OPA plugins are paid/enterprise tiers, so it is not the default for an open-source stack.
3. **Pomerium** — add in front of HTTP MCP servers when identity and zero-trust access are the primary concern.
4. **agentgateway** — keep as a fallback if the deployment later moves to Kubernetes or needs CEL-based enterprise RBAC.
5. **Bifrost** — use for LLM-provider governance (budgets, virtual keys, failover), not as the main tool-authorization layer.

**AgentWall is intentionally excluded** from the recommendation. It is conceptually the closest to the policy proxy, but its tiny user base and minimal adoption make it unsuitable as a foundation for a hardening architecture (see [16-existing-out-of-process-proxies.md](./16-existing-out-of-process-proxies.md)).

---

## What is still missing from all five

None of these projects solve the **native Hermes tool** problem. They can only protect MCP-mediated calls. Any prototype must therefore be paired with:

- Disabling `terminal`, `execute_code`, `file`, `browser`, `web`, `messaging`, `cronjob`, `delegation`, and other high-risk native toolsets.
- Replacing needed capabilities with MCP-wrapped equivalents.
- OS-level isolation for whatever cannot be replaced (see [17-hermes-native-tools-and-mcp-replacements.md](./17-hermes-native-tools-and-mcp-replacements.md)).

---

## Sources

- `IBM/mcp-context-forge` README and docs (fetched 2026-06-28)
- `kong/kong` GitHub and Kong AI/MCP Gateway docs (fetched 2026-06-28)
- `pomerium/pomerium` GitHub and Pomerium MCP blog/docs (fetched 2026-06-28)
- `agentgateway/agentgateway` README and docs (fetched 2026-06-28)
- `maximhq/bifrost` README and docs (fetched 2026-06-28)
- GitHub API star/fork counts (2026-06-28)
