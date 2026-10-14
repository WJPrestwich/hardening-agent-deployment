# Human-in-the-loop approval design

Cross-cutting concern: how does ContextForge gate dangerous operations across all MCP servers (email send, file delete, GitHub push, etc.)?

This was originally raised in [28-email-rbac-design.md](./archive/28-email-rbac-design.md) question 2 but applies to every capability where the agent should not act autonomously.

---

## Open questions

### 1. Does ContextForge support an approval-gated flow?

**Findings from ContextForge docs (v1.0.0-RC1) and ADR-022:**

- **No native pause-and-wait approval.** ContextForge cannot pause a tool call and wait for an operator decision. Its enforcement mechanisms are all synchronous allow/deny.
- **Elicitation (ADR-022) is passthrough only.** ContextForge implements the MCP 2025-06-18 elicitation spec, but only as a relay — it forwards elicitation requests from upstream MCP servers to downstream clients. The ADR explicitly rejected "Gateway-Initiated Elicitation Only." ContextForge itself cannot initiate an approval request; it can only relay one from an MCP server that does. Our MCP servers (email, filesystem, GitHub, etc.) don't initiate elicitation.
- **Plugin framework (`tool_pre_invoke` hook):** Plugins can inspect tool name + arguments and either allow or block (`continue_processing=False` + `PluginViolation`). But there's no pause-and-wait — plugins are synchronous allow/deny. A custom plugin *could* be written to implement an async approval flow (block, notify, wait for external signal, allow on retry), but that's custom development, not built-in.
- **RBAC:** Static allow/deny per tool. No approval flow.
- **Admin UI:** Web-based dashboard for managing servers, tools, config. Not an approval interface.

### 2. How does the operator approve?

**Decision: No approval interface for the first guide version.** See question 3.

### 3. Is HITL approval in scope for the first guide version?

**Decision: Deny-by-default with manual operator enablement through config adjustment.** Dangerous tools are denied by ContextForge RBAC/policy. When the operator wants to allow one, they modify the ContextForge config and reload. No pause-and-wait, no approval interface, no notification flow.

This is the simplest approach that fits ContextForge's actual capabilities. Full HITL (pause-notify-approve) would require either:
- A custom ContextForge plugin implementing async approval (custom development).
- MCP servers that initiate elicitation (none of our picks do).
- An external orchestration layer (e.g., Temporal workflows) — too complex for a single-host personal deployment.

These are deferred to a later guide version.

### 4. Which operations require approval?

Deferred to guide writing or as an exercise for the guide user. The risk tiers above are a starting framework; the specific line per-tool vs per-argument is for the operator to decide based on their threat model.

### 5. How does this interact with the parked HITL design?

**Decision:** This file un-parks the HITL design. The first guide version uses deny-by-default + manual operator enablement (per question 3). Full HITL (pause-notify-approve) is deferred to a later guide version. The parked status is now explicitly "partially addressed" — the deny-by-default pattern is in scope, the approval-gated flow is not.

---

## Next steps

- ~~Resolve question 1: ContextForge approval-gated flow capability~~ — **Resolved: no native pause-and-wait; elicitation is passthrough only; plugins are synchronous allow/deny.**
- ~~Resolve question 2: operator approval interface~~ — **Resolved: no approval interface for first guide version.**
- ~~Resolve question 3: scope for first guide version~~ — **Decided: deny-by-default with manual operator enablement through config adjustment.**
- ~~Resolve question 4: which operations require approval~~ — **Deferred to guide writing / guide user.**
- ~~Resolve question 5: relationship to previously parked HITL design~~ — **Decided: un-parked; deny-by-default in scope for first guide version, approval-gated flow deferred.**
