# Email RBAC design — DEFERRED

**Status:** Email is out of scope for this guide update. The research below is preserved for future resolution.

Addressing [25-research-summary.md](./25-research-summary.md) §4.2.

**Pick:** `taylorwilsdon/google_workspace_mcp` (MIT, 2.8k stars, 12 Google services: Gmail, Calendar, Drive, Docs, Sheets, Slides, Forms, Tasks, Contacts, Chat, Apps Script, Search). Supports OAuth 2.0/2.1 with PKCE, read-only mode, granular per-service permissions (`gmail:send`, `drive:readonly`), tool tiers (core/extended/complete), and stateless container mode.

**OAuth scope reference:** [03-email.md](./03-email.md)

---

## Open questions

### 1. How to enforce read-only-by-default with send as an elevated capability?

**Decision:** Single instance with full permissions; ContextForge gates the send tools. The server runs with all capabilities enabled, and ContextForge denies send/write tools by default. This avoids running two instances and duplicating OAuth flows. The server's own read-only mode and per-service permissions are available as defense-in-depth but are not the primary gate.

### 2. How to gate send behind ContextForge approval?

See [29-hitl-approval-design.md](./29-hitl-approval-design.md) — this is a cross-cutting concern, not email-specific.

### 3. How to prevent exfiltration via email when Pipelock can't see SMTP/IMAP traffic?

See [30-exfiltration-prevention-design.md](./30-exfiltration-prevention-design.md) — this is a cross-cutting concern, not email-specific.

### 4. How to scope OAuth tokens?

**Decision:** Request the minimum combined scope needed for the capabilities we expose. Don't rely on OAuth scope granularity as the primary permission gate — ContextForge owns that. Apply consistent always-on defaults where a scope provides a hard provider-side limit (e.g., prefer `gmail.modify` over `https://mail.google.com/` full-access to avoid granting IMAP/SMTP protocol access). But the real enforcement layer is ContextForge, not the OAuth scope.

---

## Next steps

- ~~Resolve question 1: read-only-by-default vs single-instance approach~~ — **Decided: single instance, ContextForge gates send tools.**
- ~~Resolve question 2: ContextForge approval-gated send~~ — **Promoted to [29-hitl-approval-design.md](./29-hitl-approval-design.md).**
- ~~Resolve question 3: exfiltration prevention (recipient allowlists, draft-only mode)~~ — **Promoted to [30-exfiltration-prevention-design.md](./30-exfiltration-prevention-design.md).**
- ~~Resolve question 4: OAuth token scoping and storage~~ — **Decided: minimum combined scope with always-on provider-side defaults; ContextForge is the real permission gate, not OAuth scopes.**
