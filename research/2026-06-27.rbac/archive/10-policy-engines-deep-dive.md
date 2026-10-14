# Policy engines and PDPs — deep dive

This page expands on the policy-engine summary in [04-rbac-patterns.md](./04-rbac-patterns.md). It covers what a PDP is, how policy engines work, and the open-source options available for enforcing per-tool authorization on an AI agent.

---

## What is a PDP?

A **Policy Decision Point (PDP)** is the component that takes an authorization request and returns an access decision: typically **Permit**, **Deny**, **NotApplicable**, or **Indeterminate**.

It is one piece of the classic XACML authorization architecture:

| Component                             | Role                                                                                          |
|---------------------------------------|-----------------------------------------------------------------------------------------------|
| **PEP** — Policy Enforcement Point    | Intercepts the access attempt, asks the PDP, and enforces the result. This is the gatekeeper. |
| **PDP** — Policy Decision Point       | Evaluates policies and returns the decision. This is the "brain."                             |
| **PAP** — Policy Administration Point | Where humans author, version, and publish policies.                                           |
| **PIP** — Policy Information Point    | Attribute sources the PDP queries at decision time (identity, risk score, time of day, etc.). |
| **PRP** — Policy Retrieval Point      | The policy store from which the PDP loads its rules.                                          |

Typical flow for a tool call:

```
Agent wants to call tool "send_email"
        │
        ▼
┌───────┴───────┐
│      PEP      │  (gateway, sidecar, or middleware)
│  (enforcer)   │  — collects subject/action/resource/context
└───────┬───────┘
        │ authorization request
        ▼
┌───────┴───────┐
│      PDP      │  — loads policies from PRP, fetches attributes from PIP,
│   (decider)   │    evaluates rules, returns Permit/Deny + obligations
└───────┬───────┘
        │ decision + obligations (e.g., "require human approval")
        ▼
┌───────┴───────┐
│      PEP      │  — blocks the call, allows it, or routes it to HITL
│  (enforcer)   │
└───────────────┘
```

The key idea: **decision-making is separated from enforcement**. The PEP lives close to the action so it cannot be bypassed; the PDP lives wherever policy management and audit are easiest.

---

## What do policy engines do, and how?

A policy engine is a runnable PDP. It:

1. **Stores policies** (PRP role) as code, config, or database tuples.
2. **Accepts authorization requests** containing subject, action, resource, and context attributes.
3. **Evaluates those requests** against its policies using a rule language or model (RBAC, ABAC, ReBAC, etc.).
4. **Returns a decision**, optionally with obligations/advice such as `require_approval`, `log_only`, or `rate_limit`.

How they evaluate depends on their authorization model:

- **RBAC** — membership in a role grants a set of permissions. Fast and simple, but coarse for agents that need per-tool, per-resource, or per-context decisions.
- **ABAC** — decisions are based on attributes of the subject, action, resource, and environment. More expressive: "allow `send_email` only to domains in `allowed_recipients` and only if `risk_score < 0.8` and `time_of_day` is business hours."
- **ReBAC** (relationship-based) — decisions are based on relationships between entities, e.g., "agent A is delegated by user U," "file F is in workspace W," "user U owns workspace W." Good for delegation chains and ownership graphs.

Most engines also support:

- **Policy distribution** (push or pull to sidecars).
- **Caching** (policy cache, attribute cache, decision cache) for low latency.
- **Audit logging** of every request and decision.
- **Testing/validation** of policy changes before enforcement.

---

## Open-source lay of the land

| Project                     | License                | Model                                         | Deployment                                                                  | Best fit for agent tool auth                                                                             |
|-----------------------------|------------------------|-----------------------------------------------|-----------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| **OPA** (Open Policy Agent) | Apache-2.0             | Policy-as-code (Rego); RBAC/ABAC possible     | Library, sidecar, or central service; Envoy `ext_authz` plugin              | Flexible, widely adopted; good when policies need complex logic and you can tolerate Rego learning curve |
| **Cedar**                   | Apache-2.0             | ABAC/RBAC with permit/forbid semantics        | SDKs (Rust, Java, etc.) or embedded                                         | Safe, analyzable, AWS AgentCore provenance; strong for per-tool ABAC with high-assurance needs           |
| **SpiceDB**                 | Apache-2.0             | ReBAC (Zanzibar-style)                        | Service with Postgres/CockroachDB/in-memory backends; LangChain integration | Rich delegation/ownership graphs; good when agent actions depend on who delegated whom                   |
| **OpenFGA**                 | Apache-2.0             | ReBAC (Zanzibar-style)                        | Service with SDKs; Envoy adapter                                            | Similar to SpiceDB; CNCF sandbox; good relationship-heavy authorization                                  |
| **Casbin**                  | Apache-2.0             | Library-based RBAC/ABAC/ACL                   | Library or external `envoy-authz` service                                   | Lightweight in-process checks; good for simpler policy tables                                            |
| **Cerbos**                  | Apache-2.0 (open core) | YAML + CEL; RBAC/ABAC                         | Stateless service/sidecar/DaemonSet; Envoy/Istio integrations               | Explicit agent/MCP guidance; claims sub-ms evaluation; good synchronous PDP                              |
| **Keto** (ORY)              | Apache-2.0             | ReBAC (Zanzibar-style)                        | Service; REST/gRPC                                                          | Fits Zanzibar-style use cases; check CVE/patching history                                                |
| **Topaz** (Aserto)          | Open source            | OPA (Rego) + embedded Zanzibar-like directory | Container/sidecar                                                           | Hybrid: OPA expressiveness plus relationship directory                                                   |
| **Permify**                 | Open source            | Zanzibar-inspired relationships               | Centralized Go service                                                      | Hierarchical, context-aware permissions                                                                  |
| **Ory Oathkeeper**          | Apache-2.0             | Access proxy with rules (some Rego support)   | Stateless proxy/gateway                                                     | Identity-aware reverse proxy; useful as a PEP in front of tools                                          |
| **Pomerium**                | Open source            | Identity-aware proxy; PPL YAML + Rego         | Reverse proxy/gateway                                                       | Agentic-gateway positioning; session-aware enforcement and MCP guidance                                  |

### Quick recommendations by scenario

> These are general landscape recommendations. For this project's actual decision, see [21-settled-decisions.md](./21-settled-decisions.md) §8: we use ContextForge's native RBAC/ABAC; OPA and Casbin are out of scope.

- **Low-latency synchronous tool checks**: Cerbos, OPA sidecar, or SpiceDB/OpenFGA with caching.
- **Rich delegation/ownership graphs**: SpiceDB or OpenFGA.
- **High-assurance ABAC with static analysis**: Cedar.
- **Lightweight embedded checks**: Casbin.
- **Gateway/PEP layer in front of tools**: Pomerium or Ory Oathkeeper.

---

## Modeling agent tool authorization

For an agent like Hermes, an authorization request could look like:

```json
{
  "subject": {
    "agent_id": "hermes-001",
    "user_id": "alice",
    "role": "operator"
  },
  "action": "send_email",
  "resource": {
    "type": "email_message",
    "to": "bob@example.com",
    "domain": "example.com",
    "attachment_count": 1
  },
  "context": {
    "risk_score": 0.3,
    "time_of_day": "09:00",
    "approval_token_present": false
  }
}
```

Example policy concepts:

- `send_email` is allowed only to domains in an allowlist.
- `send_email` to a new domain requires an approval obligation.
- `write_file` outside `/workspace` is denied by default.
- `exec_shell` with destructive keywords requires sync human approval.
- `install_skill` from `community` sources is denied unless the user is an admin.

Most engines let the PDP return **obligations** such as `{ "require_approval": { "timeout": 300, "channel": "telegram" } }`, which the PEP can turn into a human-in-the-loop gate.

---

## How this fits the policy proxy

For the proposed policy proxy, the architecture is:

- **PEP**: ContextForge intercepts MCP tool calls as the out-of-process gateway.
- **PDP**: ContextForge's native RBAC/ABAC engine evaluates each call (with optional Cedar plugin for more expressive policies).
- **PAP**: policies authored in ContextForge's configuration and loaded at gateway startup.
- **PIP**: context from Hermes config, runtime environment, and optionally a risk scorer.
- **Obligations**: HITL approval, rate limiting, audit logging.

The first implementation uses ContextForge's built-in policy engine on a single host. OPA and Casbin are explicitly out of scope (see [11-casbin-opa-spicedb-comparison.md](./11-casbin-opa-spicedb-comparison.md) and [21-settled-decisions.md](./21-settled-decisions.md) §8). If ContextForge's native RBAC/ABAC proves insufficient, the Cedar plugin is the next step.

---

## Sources

- OASIS XACML 3.0 core spec and JSON/HTTP profile
- NIST CSRC: policy decision point definition
- Open Policy Agent docs and Envoy integration
- Cedar policy docs and AWS AgentCore blogs
- SpiceDB docs, performance docs, LangChain integration, AI-agent tutorial
- OpenFGA docs and Envoy adapter
- Casbin docs and benchmarks
- Cerbos docs, low-latency blog, MCP/agent blogs
- ORY Keto docs and release/CVE notes
- Topaz docs
- Permify repo and HN discussion
- Pomerium agentic-gateway and MCP blogs
- Ory Oathkeeper repo
