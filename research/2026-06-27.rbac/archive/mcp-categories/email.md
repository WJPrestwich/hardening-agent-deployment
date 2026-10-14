# MCP server selection: Email (Glama #55)

Replaces: email functionality via Hermes `send_message` or `terminal`/`execute_code`.

**Major research line.** User uses Gmail. Need to figure out RBAC for email using the research we've done (ContextForge tool-level policy, OAuth scopes from `03-email.md`, approval-gated send, recipient allowlists). This is a significant design item, not just an MCP server pick.

---

## Top 10 from Glama (sorted by weekly downloads)

| # | Server | Author | DL/wk | License | Assessment |
|---|--------|--------|-------|---------|------------|
| 1 | M365 Assistant MCP | `ryaker` | 394 | MIT | — |
| 2 | AgenticMail | `agenticmail` | 151 | MIT | — |
| 3 | Sendmux | `Sendmux` | 110 | MIT | — |
| 4 | apple-mail-mcp | `s-morgan-jeffries` | 89 | MIT | — |
| 5 | mcp-google | `klemensgc` | 89 | F | **Interesting.** Gmail, Calendar, Drive, Docs, Sheets, Slides — 25 tools. Multi-account, local-first, encrypted OAuth tokens. |
| 6 | candidate-mcp-server | `jhgaylor` | 81 | MIT | — |
| 7 | Email MCP Server | `codefuturist` | 63 | LGPL 3.0 | — |
| 8 | Atomic Mail Agentic | `Atomic-Mail` | 56 | MIT | — |
| 9 | agent-inbox | `gsd-build` | 51 | MIT | — |
| 10 | IMAP MCP Server | `nikolausm` | 47 | MIT | — |

---

## Candidates

| Capability | Pick | Status |
|-----------|------|--------|
| Gmail + Google Workspace | `klemensgc/mcp-google` | **Candidate.** 25 tools across Gmail, Calendar, Drive, Docs, Sheets, Slides. Multi-account, local-first, encrypted OAuth tokens. Note: F license — needs investigation. |

---

## RBAC design considerations

This category is a major research line, not just a server pick. Key questions:

- How to enforce recipient allowlists for send operations?
- How to gate send behind ContextForge approval?
- How to scope OAuth tokens (Gmail readonly vs send vs modify)?
- How to prevent exfiltration via email (Pipelock can't see SMTP/IMAP traffic — need the MCP server to enforce)?
- Should email be read-only by default with send as an opt-in elevated capability?

These questions need to be resolved during the guide update phase, using the research in `03-email.md` and `21-settled-decisions.md` §9.
