# Settled decisions

This page records decisions that are unlikely to change, so later work can build on them without rehashing the same arguments.

---

## 1. Hermes native tools are a security boundary problem, not a policy problem

Hermes runs its built-in tools in-process and loads skills/plugins from writable directories. That design cannot be made safe by adding more in-process policy. The only viable approach is to disable the high-risk native toolsets and replace needed capabilities with out-of-process MCP servers.

See [20-hermes-tool-exposure-risk-assessment.md](./archive/20-hermes-tool-exposure-risk-assessment.md) and [17-hermes-native-tools-and-mcp-replacements.md](./17-hermes-native-tools-and-mcp-replacements.md).

---

## 2. The MCP gateway is ContextForge

We will reuse an existing open-source gateway rather than build one. **ContextForge** is the primary choice because:

- It is Apache 2.0 and purpose-built for MCP.
- It runs as a single container with SQLite (or scales to PostgreSQL + Redis).
- It federates MCP, A2A, and REST backends behind one governed endpoint.
- It has native RBAC/ABAC, plus optional Cedar and OPA plugins, so we do not need a separate policy sidecar for the first implementation.
- It includes 35+ security plugins (PII filter, deny filter, schema guard, rate limiting, etc.) out of the box.

Kong Gateway is still a viable fallback for teams that already run Kong Enterprise, but its AI MCP Proxy and OPA plugins are paid/enterprise tiers. For an open-source hardening guide, ContextForge is the better default.

See [18-mcp-proxy-comparison-matrix.md](./18-mcp-proxy-comparison-matrix.md).

---

## 3. AgentWall and other tiny MCP-security projects are not a foundation

AgentWall is conceptually close to what we want, but its 34-star user base and minimal adoption make it unsuitable as the foundation of a hardening architecture. We will watch it, and similar small projects, but not rely on them.

See [16-existing-out-of-process-proxies.md](./16-existing-out-of-process-proxies.md).

---

## 4. `pre_tool_call` and in-process plugins are not an enforcement boundary

Any guard that lives inside the Hermes Python process can be bypassed by `execute_code`, `terminal`, a malicious skill, or a plugin override. We will use out-of-process proxies and OS-level controls for enforcement, and reserve `pre_tool_call` for logging or telemetry only.

See [13-pre-tool-call-poor-fit.md](./archive/13-pre-tool-call-poor-fit.md).

---

## 5. Pipelock is the egress control; CrabTrap is out of scope

We will rely on **Pipelock** for deterministic egress control and DLP, not on an LLM-as-a-judge proxy.

**Why we dropped CrabTrap.**

- Pipelock already provides domain/path allowlists, DLP body scanning, and signed evidence receipts.
- CrabTrap adds an LLM judge, PostgreSQL, and an LLM backend to the stack — more latency, cost, and moving parts for a personal deployment.
- The LLM judge is probabilistic, so it is a poor primary enforcement boundary.
- CrabTrap only sees HTTP/HTTPS traffic; the real safety comes from disabling native Hermes tools and using ContextForge for MCP authorization.

**What Pipelock does for us.**

- Intercepts outbound HTTP/HTTPS from the Hermes container and HTTP-based MCP servers.
- Enforces destination domain/path allowlists.
- Scans bodies for DLP patterns and sensitive credentials.
- Writes signed evidence receipts for audit.

**Deployment intent.** Route all outbound HTTP/HTTPS traffic from the agent and MCP servers through Pipelock. Keep the allowlist strict and fail-closed; any destination not on the list is denied.

See [16-existing-out-of-process-proxies.md](./16-existing-out-of-process-proxies.md).

---

## 6. We are keeping Hermes despite its security liabilities

**Why we considered dropping it.** Hermes ships with roughly 71 native tools across ~29 toolsets, all running in-process inside the same Python interpreter as the agent loop, skills, plugins, and configuration. Its own `SECURITY.md` states that the only real security boundary against an adversarial LLM is the operating system, and independent audits have confirmed an allow-all default posture with multiple Critical/High findings. From a pure security perspective, a smaller custom harness (LLM + MCP proxy + sandboxed execution) would be a cleaner foundation.

**Why we are keeping it anyway.** No alternative we evaluated provides the same combination of features that matter for this project:

- **Multi-platform messaging gateway** — Telegram, Discord, Slack, WhatsApp, Signal, email, SMS, etc., out of the box.
- **Persistent memory + auto-generated skills** — the agent recalls prior sessions and writes reusable `SKILL.md` files from experience.
- **Model-agnostic deployment** — works with Nous Portal, OpenRouter, OpenAI, Anthropic, local models, and custom endpoints without code changes.
- **Skills Hub / MCP catalog** — one-click community skills and MCP servers.
- **Web dashboard, desktop app, CLI/TUI, subagent delegation, cron scheduling, and MLOps/RL trajectory export.**

Switching to OpenClaw, Claude Agent SDK, OpenAI Agents SDK, Smolagents, LangGraph, or CrewAI would mean rebuilding one or more of those capabilities ourselves. OpenClaw is functionally closest but has the same structural risks and its own CVE list; the SDKs are simpler but lack messaging, memory, and skills; Smolagents has better sandboxing but is a single-agent library with no gateway or persistent memory.

**What this implies.** Hermes will be treated as an untrusted workload inside an OS-level sandbox. The hardening strategy is not "add policy on top of Hermes"; it is "disable or relocate almost all of Hermes' native power, then put trusted proxies and sandboxes in front of the small set of capabilities that remain." The policy proxy, MCP gateway, egress controls, and container isolation are there to contain Hermes, not to make Hermes itself safe.

See [20-hermes-tool-exposure-risk-assessment.md](./archive/20-hermes-tool-exposure-risk-assessment.md) and the web-search findings summarized there.

---

## 7. Generated code is scanned by LlamaFirewall CodeShield

Before any LLM-generated code runs, it will be passed through **LlamaFirewall CodeShield**. CodeShield combines fast regex screening with Semgrep-based AST analysis, covers eight languages and 50+ CWEs, and is optimized for sub-second latency in an agent loop.

We evaluated a custom Semgrep + Bandit + CodeQL pipeline (see [22-static-analysis-for-generated-code.md](./22-static-analysis-for-generated-code.md)) and concluded that CodeShield already is that pipeline, with a curated rule set maintained by Meta's Purple Llama project. Rebuilding it ourselves would add maintenance burden without improving coverage.

Deployment model: CodeShield runs as a **container in the stack**, not inside the Hermes container. A small wrapper exposes a local HTTP endpoint (e.g., `POST /scan/code`) that Hermes' `execute_code` path or any MCP code-execution server calls before running generated code. A compromised Hermes process cannot monkey-patch a separate container.

PromptGuard and Agent Alignment Checks are **off by default**. They can be revisited later as optional input/reasoning filters, but the immediate need is deterministic generated-code scanning.

See [22-static-analysis-for-generated-code.md](./22-static-analysis-for-generated-code.md) and [23-llamafirewall-fit-assessment.md](./23-llamafirewall-fit-assessment.md).

---

## 8. We are NOT implementing OPA or Casbin

The policy layer for this project is **ContextForge's built-in RBAC/ABAC**. We are not adding a separate policy engine.

- **OPA is overkill** for a single-host personal deployment. It adds a Rego learning curve, a separate service, and policy-as-code workflow overhead that we do not need.
- **Casbin is also out of scope.** It was briefly considered as a lightweight in-process option, but with ContextForge as the gateway there is no place for it.
- **If ContextForge's native RBAC/ABAC proves insufficient, the next option is ContextForge's Cedar plugin**, which is local, analyzable, and purpose-built for authorization. OPA is explicitly not on the implementation path.

See [11-casbin-opa-spicedb-comparison.md](./11-casbin-opa-spicedb-comparison.md) for the comparison that led to this decision.

---

## 9. We are NOT using a credential broker

We will **not** deploy ClawShell, Infisical Agent Vault, or any other credential-brokering proxy. Credentials for LLM providers, GitHub, email, and MCP servers will live in the Hermes/MCP-server environment as **tightly scoped, static credentials**.

**Why this is acceptable here.**

- It matches Pipelock’s intended security model: the agent holds scoped credentials but cannot reach the internet except through Pipelock’s scanning proxy.
- It avoids the operational and maintenance burden of running an additional MITM proxy (or a custom multi-scanner proxy) on a single-host deployment.
- It avoids relying on a research-preview project (Agent Vault) or maintaining two separate proxies (ClawShell + Agent Vault).
- ContextForge provides tool-level policy on MCP-mediated actions, which compensates for some of the semantic misuse risk.

**Accepted costs and residual risks.**

- **Credential possession.** A compromised agent still has real credentials in memory/environment. Pipelock DLP + domain allowlists block the most common exfiltration paths, but they cannot block every encoded or steganographic leak.
- **Semantic misuse on allowed endpoints.** Pipelock sees bytes, not tool intent. A prompt-injected agent could still use a scoped GitHub PAT on `api.github.com` to delete repos, or a scoped SMTP password to send unwanted mail, if those endpoints are allowlisted. Mitigation comes from ContextForge tool-level policy and from scoping the credentials tightly (e.g., read-only GitHub PAT, send-restricted OAuth).
- **No short-lived tokens.** Stolen credentials remain usable until rotated. We rely on provider-side rotation, narrow scopes, and monitoring rather than on-demand token issuance.
- **LLM-channel DLP is lost.** ClawShell previously scanned LLM request/response bodies for PII/credentials. That function is removed; Pipelock still scans egress bodies and responses, but the LLM provider channel is now only protected by Pipelock’s general DLP patterns and by provider-side controls.

**Mitigations we keep.**

- **Pipelock** for egress allowlisting, DLP, response injection scanning, SSRF protection, and signed audit receipts.
- **ContextForge** for per-tool/per-argument allow/deny and approval gating on MCP-mediated actions.
- **Scoped credentials** — fine-grained PATs, OAuth-scoped tokens, app passwords, and per-MCP-server keys with the minimum permissions required.
- **OS/container isolation** — the agent cannot reach the network except via Pipelock.


---

## Open decisions

- None. Runtime integrity is decided and HITL is parked for a later session.

---

## Runtime integrity decisions

- **No read-only mounts** for `~/.hermes/plugins/` and `~/.hermes/skills/`.
- **`execute_code` is disabled entirely.** Replaced by **`vndee/llm-sandbox`** MCP server (MIT, Docker/Podman, `SANDBOX_NETWORK_MODE=none`, read-only, cap-drop ALL). See [24-mcp-server-selection.md](./24-mcp-server-selection.md).
- **`terminal` is disabled entirely.** Replaced by the same **`vndee/llm-sandbox`** MCP server, which can run shell commands in isolated containers. Using one server for both code and shell reduces component count.
- Plugin/skill integrity will rely on operator install from trusted sources plus periodic audit, rather than filesystem immutability.
