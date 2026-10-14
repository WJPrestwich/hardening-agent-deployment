# Existing out-of-process proxies and gateways for agent tool calls

This page surveys libraries and frameworks that can enforce policy on AI agent tool calls from outside the agent process, with a focus on what works with Hermes. The goal is to reuse **widely-used, well-trusted** software rather than betting the architecture on a brand-new project with a tiny user base.

---

## What we need

Hermes has two tool paths:

1. **Native Hermes tools** — registered in the in-process tool registry (`terminal`, `read_file`, `execute_code`, `send_message`, etc.).
2. **MCP-mediated tools** — Hermes connects as an MCP client to stdio or HTTP MCP servers, and those tools appear alongside native tools.

An out-of-process proxy can only protect path #2 unless Hermes exposes a stable, out-of-process execution boundary for native tools (which it currently does not). Therefore the survey splits into:

- **MCP proxies/gateways** — usable today for all MCP tools Hermes calls.
- **Runtime guardrails** — model/input/output safety layers that do not intercept individual tool calls.
- **Network/credential proxies** — egress and secret controls that complement but do not replace tool-level policy.

---

## Selection principle: trust and adoption first

We are not looking for the project that is *conceptually* closest to the policy proxy. We are looking for software that is:

- Already used in production by many organizations.
- Backed by a credible open-source community, foundation, or vendor.
- Likely to still be maintained in two years.
- Capable of transparently proxying MCP tool calls from Hermes.

That rules out several small, recently-announced MCP security wrappers. They may become interesting later, but they are not a safe foundation today.

---

## Mature / widely-used options that can proxy MCP tools

These projects have substantial real-world usage, strong governance, and an MCP proxy or gateway mode that Hermes can talk to.

| Project                | Repo                                  | Stars / forks (2026-06-28) | Why it is credible                                                              | MCP proxy model                                                       |
|------------------------|---------------------------------------|----------------------------|---------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| **Kong Gateway**       | `kong/kong`                           | 43,686 / 5,160             | De-facto open-source API gateway; enterprise track record; Apache 2.0 core.     | MCP Proxy plugin*, MCP OAuth2 plugin*, OPA/Key-auth plugins* (*enterprise tier). |
| **Pomerium**           | `pomerium/pomerium`                   | 4,872 / 339                | Mature identity-aware proxy; zero-trust access; active CNCF-adjacent community. | Identity-aware access to MCP servers; JWT/SSO at the edge.            |
| **ContextForge**       | `IBM/mcp-context-forge`               | 3,974 / 725                | IBM-backed; large contributor base; explicit MCP/A2A/REST gateway mission.      | Virtual MCP servers; Cedar/OPA/native RBAC; stdio/HTTP/SSE wrapper.   |
| **agentgateway**       | `agentgateway/agentgateway`           | 3,552 / 597                | Linux Foundation project; K8s Gateway API + standalone modes.                   | MCP gateway with stdio/SSE/HTTP/streamable-HTTP; CEL RBAC.            |
| **Bifrost**            | `maximhq/bifrost`                     | 6,090 / 815                | Established high-performance AI gateway; large community; enterprise users.     | MCP gateway mode; governance plugins; virtual keys / budget controls. |
| **Envoy AI Gateway**   | `envoyproxy/ai-gateway`               | 1,790 / 288                | CNCF Envoy project; proven L7 proxy; full June 2025 MCP spec support.           | MCP server multiplexing, tool routing/filtering, upstream auth.       |
| **Docker MCP Gateway** | `docker/mcp-gateway`                  | 1,471 / 249                | Docker ecosystem; container-per-server isolation; OCI catalog.                  | Interceptor pattern inside Docker Desktop / Docker CLI ecosystem.     |
| **Gravitee**           | `gravitee-io/gravitee-api-management` | 424 / 114                  | Long-running open-source API management platform; enterprise users.             | MCP proxy with method-level ACL, OAuth 2.1, analytics.                |

For a single-host Hermes deployment, the practical starting points are:

- **ContextForge** — the best open-source default: Apache 2.0, purpose-built for MCP, Cedar/OPA/native RBAC, single-container SQLite mode, and 35+ security plugins.
- **Kong Gateway** — the most mature general-purpose gateway, but the AI MCP Proxy and OPA plugins are enterprise/paid tiers. Use it only if you already have a Kong Enterprise/Konnect license.
- **Pomerium** — if the first concern is *identity and access* to MCP servers rather than per-tool argument policy.
- **Bifrost** — if you also want LLM-provider governance (budgets, virtual keys, failover) in the same gateway.

---

## Smaller or newer MCP-focused projects

These are more narrowly focused on MCP security, but they have not yet achieved the adoption or governance maturity of the list above. Watch them, but do not build the foundation on them yet.

| Project                  | Repo                         | Stars / forks (2026-06-28) | Notes                                                                                                                       |
|--------------------------|------------------------------|----------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| **MCPX** (Lunar.dev)     | `TheLunarCompany/lunar`      | 463 / 38                   | Control plane, tool groups, risk-evaluation sandbox. MIT core + enterprise tier.                                            |
| **Invariant Guardrails** | `invariantlabs-ai/invariant` | 433 / 47                   | Transparent MCP/LLM proxy; deterministic rules. Mostly SaaS / dedicated deployments.                                        |
| **AgentWall**            | `agentwall/agentwall`        | 34 / 2                     | Conceptually the closest to the policy proxy (MCP proxy + HITL + audit), but extremely small user base and unproven at scale. |
| **Agent-Wall** (Node.js) | `agent-wall/agent-wall`      | 5 / 1                      | Tiny project; not a safe foundation.                                                                                        |

**AgentWall is the best conceptual match** for a human-in-the-loop MCP proxy, but its 34 stars and small contributor base make it the *worst* option for a production-hardening architecture today. If it matures, revisit it.

---

## Model/prompt guardrails (not tool-call proxies)

These are useful as additional layers but do not replace a tool-call proxy:

| Project                               | What it does                                                  | Why it is not enough alone                                          |
|---------------------------------------|---------------------------------------------------------------|---------------------------------------------------------------------|
| **LlamaFirewall** (Meta)              | Prompt injection detector, agent alignment checks, CodeShield | Scores/audits; does not enforce at the host execution boundary.     |
| **NeMo Guardrails** (NVIDIA)          | Programmable dialog/topical rails via Colang                  | Conversation-level, not per-tool argument enforcement.              |
| **Guardrails AI**                     | Output validation                                             | Output schemas, not tool authorization.                             |
| **Galileo Agent Control**             | Open-source control plane                                     | Framework-level governance; not a transparent MCP proxy.            |
| **AI EdgeLabs / Parallax**            | Runtime guardrails at message/tool-call lifecycle             | Evaluator chain; more network/host oriented than MCP tool semantic. |
| **CrabTrap**                          | LLM-as-a-judge HTTP proxy                                     | HTTP-layer judgment, not MCP tool-level policy.                     |
| **AIRG** (runtime governance library) | Intercepts tool calls via plugin                              | Still a plugin/library pattern; not necessarily out-of-process.     |
| **McpVanguard / VEX**                 | Transparent MCP interception + cryptographic audit            | Early; worth watching.                                              |

---

## Network / credential proxies (complementary controls)

These are not MCP-aware but reduce blast radius when placed alongside an MCP gateway.

| Project               | What it does                                        | How it complements an MCP proxy                                          |
|-----------------------|-----------------------------------------------------|--------------------------------------------------------------------------|
| **Pipelock**          | AI egress proxy; HTTP/HTTPS/MCP/WebSocket filtering | Catches exfiltration and SSRF that the MCP proxy misses.                 |
| **Cordon** (Codezero) | HTTPS egress credential-injection proxy             | Keeps API keys out of the agent process. Has a Hermes integration guide. |
| **Tirith**            | Hermes built-in command scanner                     | Fail-closed pattern check before shell execution.                        |

---

## Hermes-native proposals (not yet shipped)

- **Issue #16462** — first-invoke approval for MCP server tools. Not yet implemented; would add a one-time approval prompt per MCP tool, but still in-process.
- **Issue #4656** — credential proxy daemon for Hermes. Proposes a sidecar that intercepts outbound HTTPS and swaps credential placeholders. Not a tool-call policy proxy, but a useful complementary control.
- **Issue #25262** — add pre/post tool-call hooks to the plugin context API. AgentGuard/AgentWall have asked for this to build a native Hermes adapter. Even if added, these hooks remain in-process and therefore are not a security boundary (see [13-pre-tool-call-poor-fit.md](./13-pre-tool-call-poor-fit.md)).

---

## Implications for the policy proxy

1. **Do not build a generic MCP gateway from scratch.** Mature open-source gateways already exist. Reuse one of the trusted options above.

2. **Prefer adoption and governance over conceptual neatness.** AgentWall is the closest idea to the policy proxy, but its tiny user base makes it a poor foundation. Kong, ContextForge, agentgateway, Bifrost, Pomerium, and Envoy are safer starting points.

3. **Native Hermes tools are still the hard part.** An MCP proxy cannot intercept `terminal`, `execute_code`, or `read_file` unless we disable those native tools and replace them with MCP-wrapped equivalents (e.g., a sandboxed filesystem MCP server, a containerized terminal MCP server).

4. **Recommended evaluation order for a single-host Hermes deployment:**
   - **ContextForge** first. It is the best open-source default: purpose-built for MCP, native RBAC/ABAC, Cedar/OPA plugins, and a single-container SQLite mode.
   - **Kong Gateway** only if you already have a Kong Enterprise/Konnect license; its AI MCP Proxy and OPA plugins are paid tiers.
   - **Pomerium** if identity-aware access control is the primary concern.
   - **Bifrost** if LLM-provider governance must live in the same gateway.
   - **agentgateway** if the deployment is willing to accept Kubernetes or a standalone Rust/Go proxy.

5. **For native tools, pair the MCP gateway with:**
   - `terminal.backend: docker` or an SSH terminal backend so shell commands run in an isolated environment.
   - Disabling `execute_code` or forcing it to a remote/container backend.
   - Landlock/AppArmor to restrict filesystem access to `/workspace`.

---

## Sources

- `kong/kong` GitHub and Kong AI/MCP Gateway documentation
- `pomerium/pomerium` GitHub and docs
- `IBM/mcp-context-forge` GitHub and docs
- `agentgateway/agentgateway` GitHub and docs
- `maximhq/bifrost` GitHub and docs
- `envoyproxy/ai-gateway` GitHub and announcement
- `docker/mcp-gateway` GitHub and docs
- `gravitee-io/gravitee-api-management` GitHub and MCP Proxy docs
- `TheLunarCompany/lunar` / Lunar.dev MCPX documentation
- `invariantlabs-ai/invariant` GitHub and docs
- `agentwall/agentwall` GitHub and arXiv 2605.16265
- Reddit r/mcp "I built an open-source security gateway for MCP servers"
- Reddit r/node "Agent-Wall open-source security firewall for MCP"
- Codezero Cordon / Hermes Agent guide
- Pipelock documentation
- GitHub issues #16462, #4656, #25262 in `NousResearch/hermes-agent`
