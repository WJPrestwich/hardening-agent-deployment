# Access control and blast-radius planning for the hardened Hermes agent

Date: 2026-06-27
Goal: Research, design, and document how to reduce the blast radius of a malfunctioning or compromised Hermes agent. RBAC is one tool in this space, but we also need isolation, policy enforcement, human approval, audit, credential scoping, and compensating controls where no good off-the-shelf guardrail exists.

Scope includes:

- What Hermes can do natively.
- What users typically add via MCP servers and skills.
- Existing guardrails already in the hardening guide (Pipelock, Tirith, container isolation, network isolation).
- Non-RBAC approaches that complement RBAC: mandatory access control, sandboxing, rate limiting, time-bound credentials, immutable state, human-in-the-loop approval, deception/honeypots, and observability.
- Gaps where we may need to build custom software (a policy proxy/sidecar, approval queue, etc.).

---

## What we suspect (working hypotheses)

### 1. Hermes has powerful built-in capabilities that already need containment

- Reads/writes files, runs shell commands, searches code, browses the web, fetches URLs, manages cron jobs, and can spawn subagents.
- Loads skills from public hubs (`skills-sh`, `browse-sh`, `well-known`, etc.) and executes them as first-class tools.
- Connects to MCP servers as a client; MCP tools appear alongside native tools.
- Supports messaging gateways (Telegram, Discord, Slack, etc.) that can receive instructions and exfiltrate data.
- Has its own security scanner (`Tirith`) and a skills guard, but the guide currently treats those as on/off switches rather than fine-grained policies.

### 2. The current hardening stack is mostly network- and host-centric

- Credentials live in the agent/MCP-server environment as tightly scoped static tokens. **Pipelock** compensates with egress allowlisting, DLP, response scanning, and audit receipts.
- **Pipelock** filters egress by destination domain and DLP patterns, but it does not understand Hermes tools, MCP tool names, or email-specific actions.
- **Tirith** scans commands before execution, but it is pattern-based and may not cover high-level actions like "send email to X" or "delete calendar event Y".
- The container isolation is coarse: the agent either has access to a bind mount or it does not; there is no per-tool or per-skill filesystem policy.

### 3. Email is a high-impact, high-risk integration

Email is a representative "dangerous capability":

- Read/search: leaks sensitive data, enables reconnaissance, can be used for spear-phishing or credential-reset attacks.
- Send: enables spam, phishing, data exfiltration, social engineering.
- Delete/move/filters: destructive.
- OAuth providers (Gmail, Microsoft Graph) offer scopes, but the agent may still need *some* send access. We likely want an approval gate or destination/recipient allowlist.

### 4. RBAC should be layered, not a single switch

Likely layers:

1. **Container/runtime RBAC**: non-root user, dropped capabilities, read-only rootfs, AppArmor/SELinux, seccomp, network namespace, cgroup limits.
2. **Credential scope**: short-lived, least-privilege tokens; per-provider virtual keys; OAuth scopes; app-passwords vs. full account access.
3. **Network/policy RBAC**: Pipelock domain/path allowlists, MCP proxy, firewall rules, rate limits.
4. **Tool/skill RBAC**: per-skill and per-MCP-server permissions; allow/deny lists; trust tiers; tool-name filtering in Hermes config.
5. **Action-level RBAC**: human-in-the-loop approval for email send, large file transfers, writes outside the workspace, destructive commands, subagent spawning.
6. **Audit**: signed receipts, command logs, egress evidence, immutable incident snapshots.

### 5. We will probably need custom compensating controls

Hermes may not expose enough native RBAC for some activities. Suspected gaps:

- No native per-tool approval queue for MCP/native tools.
- No native per-recipient email policy.
- No native per-file or per-directory write policy beyond OS permissions.
- No native scoping of which skills may use which MCP servers.
- No native short-lived credential issuance.

Candidate custom controls:

- A small **policy proxy/sidecar** that sits between Hermes and MCP servers/ native tools, enforcing allow/deny lists, rate limits, required approvals, and audit logging.
- An **email egress gateway** that wraps an SMTP/IMAP MCP server, enforcing recipient-domain allowlists, attachment restrictions, daily send limits, and require-approval thresholds.
- A **workspace jail** that uses bind mounts + Linux ACLs + a FUSE overlay or Landlock/Unprivileged Mount namespace to restrict file access.

### 6. Non-RBAC approaches are at least as important as role definitions

RBAC answers "who/skill/tool can do what," but many of the strongest controls for an agent are not role-based:

- **Isolation**: run the agent in a sandboxed container, VM, gVisor, or rootless namespace so a compromise cannot reach the host.
- **Mandatory access control (MAC)**: AppArmor/SELinux/Landlock rules that restrict *what* a process can access regardless of Unix UID.
- **Immutability**: read-only rootfs, read-only config, versioned state backups, and snapshot-before-write make destructive actions recoverable.
- **Rate and resource limits**: cgroup limits, per-tool rate limits, daily send quotas, and request budgets slow down misuse and accidental runaway behavior.
- **Time-bound credentials**: short-lived OAuth tokens, STS-style credentials, and expiring virtual keys limit the window of abuse.
- **Human-in-the-loop**: synchronous or asynchronous approval for high-risk actions, with a separate out-of-band channel.
- **Observability and audit**: detailed, signed, tamper-evident logs and egress evidence so misuse is detected and investigated, not just prevented.
- **Deception**: canary files, honeypot recipients/domains, and fake secrets to detect unauthorized access or exfiltration attempts.
- **Fail-closed defaults**: deny by default when a policy check cannot run, mirroring the existing `tirith_fail_open: false` principle.

The final architecture should treat RBAC as one layer inside a broader "defense-in-depth" design.

---

## Active research and findings

| # | Topic | Findings |
|---|-------|----------|
| 17 | [Hermes native tools and MCP replacements](./17-hermes-native-tools-and-mcp-replacements.md) | Full built-in tool inventory and mitigation mapping |
| 18 | [MCP proxy comparison matrix](./18-mcp-proxy-comparison-matrix.md) | Top candidate gateways evaluated for Hermes |
| 21 | [Settled decisions](./21-settled-decisions.md) | All decisions unlikely to change |
| 22 | [Static analysis for generated code](./22-static-analysis-for-generated-code.md) | CodeShield selection rationale |
| 23 | [LlamaFirewall fit assessment](./23-llamafirewall-fit-assessment.md) | LlamaFirewall integration design |
| 24 | [MCP server selection targets](./24-mcp-server-selection.md) | Mapping of Hermes toolsets to specific MCP server picks |
| 25 | [Research summary](./25-research-summary.md) | Single-file summary of all research conclusions for the guide update |
| 26 | [Proposed guide outline](./26-guide-outline.md) | Section-by-section outline for the guide update |
| 29 | [HITL approval design](./29-hitl-approval-design.md) | Human-in-the-loop approval: deny-by-default, ContextForge config gating |
| 30 | [Exfiltration prevention design](./30-exfiltration-prevention-design.md) | Open questions on content inspection, recipient allowlists, draft-only mode |
| 31 | [Operator interface and observability](./31-operator-interface-and-observability.md) | Hermes interfaces inventory; decision to rely on native interfaces with out-of-process audit backstop |

## Archived background research

These files are still correct but have been superseded by settled decisions, absorbed into later pages, or deferred to a future guide version. They have been moved to [`./archive/`](./archive/).

| # | Topic | Reason |
|---|-------|--------|
| 00 | [Research avenues](./archive/00-research-avenues.md) | Initial brainstorm, superseded |
| 01 | [Hermes native security primitives](./archive/01-hermes-native.md) | Absorbed into `17`/`20`/`21` |
| 02 | [MCP server security model](./archive/02-mcp-servers.md) | Absorbed into `17`/`24`/`21` |
| 03 | [Email integration scopes](./archive/03-email.md) | Email deferred to future guide version |
| 04 | [Existing agent RBAC patterns](./archive/04-rbac-patterns.md) | Absorbed into `10`/`11`/`21` |
| 05 | [Container and host-level MAC](./archive/05-container-mac.md) | Superseded |
| 06 | [Human-in-the-loop approval workflows](./archive/06-human-in-the-loop.md) | Absorbed into `29` |
| 07 | [Credential scoping and short-lived tokens](./archive/07-credentials.md) | Decision made (no broker) |
| 08 | [DLP and content filtering beyond HTTP](./archive/08-dlp-smtp-imap.md) | Superseded |
| 09 | [Non-RBAC blast-radius controls](./archive/09-sandboxing.md) | Superseded |
| 10 | [Policy engines and PDPs deep dive](./archive/10-policy-engines-deep-dive.md) | Decision made (ContextForge native RBAC) |
| 11 | [Casbin vs. OPA vs. SpiceDB](./archive/11-casbin-opa-spicedb-comparison.md) | Decision made, `21` §8 |
| 12 | [Hermes tool-call authorization with Casbin](./archive/12-hermes-casbin-tool-authorization.md) | Rejected design |
| 13 | [Why `pre_tool_call` is a poor security boundary](./archive/13-pre-tool-call-poor-fit.md) | Settled (§3.3), absorbed into `21`/`25` |
| 14 | [Known guide deficiencies](./archive/14-guide-deficiencies-and-gaps.md) | Superseded by `25`/`26` — all gaps resolved or deferred |
| 15 | [Remaining RBAC work items](./archive/15-remaining-rbac-work-items.md) | Superseded by `25`/`26` |
| 16 | [Existing out-of-process proxies and gateways](./archive/16-existing-out-of-process-proxies.md) | Decision made (ContextForge) |
| 19 | [Model/prompt guardrails deep dive](./archive/19-model-prompt-guardrails-deep-dive.md) | Decision made, covered in `22`/`23` |
| 20 | [Hermes tool exposure risk assessment](./archive/20-hermes-tool-exposure-risk-assessment.md) | Settled, absorbed into `21`/`25` |
| 24a | [MCP category triage](./archive/24a-mcp-category-triage.md) | Selections made; `24` is the reference |
| 27 | [Filesystem deployment architecture](./archive/27-filesystem-deployment-architecture.md) | Filesystem MCP server deferred; design preserved |
| 28 | [Email RBAC design](./archive/28-email-rbac-design.md) | Email deferred to future guide version |
| — | [MCP category investigations](./archive/mcp-categories/) | Per-category investigation artifacts; picks consolidated in `24` |

---

## Proposed architecture sketch

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Operator / out-of-band approval channel (Telegram/Discord/Slack/Web)   │
└─────────────────────────────────────────────────────────────────────────┘
                                     ▲
                                     │ approve / deny
┌───────────────────────────────────┼─────────────────────────────────────┐
│ Host                              │                                     │
│  ┌──────────────────────┐  ┌─────────────────────────────────────────┐ │
│  │ ContextForge         │  │ MCP servers (stdio / local)             │ │
│  │ - tool allow/deny    │  │ - filesystem (allowed paths only)       │ │
│  │ - per-arg policy     │  │ - email gateway (approval-gated send)   │ │
│  │ - approval gating    │  │ - git / GitHub (scoped PAT)             │ │
│  └──────────┬───────────┘  └─────────────────────────────────────────┘ │
│             │                                                         │
│             │ stdio / local                                           │
│  ┌──────────┴────────────────────────────────────────────────────────┐│
│  │ Hermes container (agent)                                           ││
│  │  - non-root, --cap-drop ALL, --read-only                           ││
│  │  - scoped static credentials for LLM, GitHub, SMTP, MCP servers    ││
│  │  - Tirith fail-closed, disabled_toolsets                           ││
│  └────────────────────────┬───────────────────────────────────────────┘│
│                           │                                           │
│                           │ HTTPS_PROXY / transparent proxy           │
│  ┌────────────────────────┴──────────────────────────────────────────┐│
│  │ Pipelock                                                             ││
│  │  - egress allowlisting  - DLP scanning  - audit receipts             ││
│  └─────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────┘
```

Key design decisions:

1. **Hermes container remains the coarse boundary** (non-root, read-only, dropped caps, isolated bridge, cgroup limits).
2. **ContextForge** fronts the MCP servers, applying tool allow/deny lists, per-argument policy, rate limits, and approval gating, and writing audit records.
3. **Email** is handled by a dedicated read-only-by-default MCP gateway. Send actions are routed through ContextForge for synchronous approval and destination/recipient allowlisting.
4. **Credentials live in the Hermes/MCP-server environment as tightly scoped static tokens.** No credential broker is used. Pipelock DLP, egress allowlisting, ContextForge policy, and provider-side scoping are the compensating controls. This is an accepted residual risk.
5. **Pipelock** enforces deterministic network egress and HTTP DLP for all outbound traffic; non-HTTP email traffic is brokered by the email gateway before Pipelock sees it.


---

## Proposed guide outline

A new top-level section or page in the hardening guide:

1. **Access control overview** — why RBAC alone is not enough; layers of defense.
2. **Hermes-native controls** — Tirith fail-closed, `disabled_toolsets`, Blank Slate mode, skill trust tiers, tool approval modes.
3. **MCP server governance** — allow/deny lists, local stdio vs remote HTTP, wrapping servers with `pipelock mcp proxy`, per-server credentials.
4. **Email hardening** — OAuth scopes for Gmail/Graph, choosing read-only vs send, approval-gated send gateway, provider-side controls.
5. **Policy proxy** — architecture, config schema, approval queue, audit logging. Provide a reference implementation.
6. **Credential scoping** — no credential broker; use tightly scoped static credentials, provider-side rotation, and compensating controls (Pipelock DLP, ContextForge policy).
7. **Resource and rate limits** — cgroup v2 limits, per-tool and daily send quotas.
8. **Human-in-the-loop** — sync vs async approval, platform UX patterns, audit fields.
9. **Verification checklist** — prove each layer is enforced.

---

## Status

The architecture research phase is largely complete. The core strategy is settled:

- Hermes remains as an **untrusted workload** inside OS/container isolation.
- High-risk native Hermes tools are **disabled or relocated** to out-of-process MCP servers.
- **ContextForge** fronts the MCP servers.
- **No credential broker is used.** Credentials live in the Hermes/MCP-server environment as tightly scoped static tokens; Pipelock and ContextForge compensate.
- **Pipelock** handles deterministic egress and DLP; CrabTrap is out of scope.
- **LlamaFirewall CodeShield** scans generated code before execution.
- `pre_tool_call` and in-process plugins are **not enforcement boundaries**.

See [21-settled-decisions.md](./21-settled-decisions.md) for the full list.

## Next step

Begin the guide update using [25-research-summary.md](./25-research-summary.md) as the single-file reference. The summary consolidates all settled decisions, MCP server selections, open items, and the proposed guide outline.
