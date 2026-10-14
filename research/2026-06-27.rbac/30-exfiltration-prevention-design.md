# Exfiltration prevention design

Cross-cutting concern: how to prevent data exfiltration through channels that Pipelock cannot inspect.

**Note:** Email was the original trigger for this file but is now deferred (see [28-email-rbac-design.md](./archive/28-email-rbac-design.md)). The questions below remain relevant for other outbound channels: GitHub (public gists, public repos, issue/PR bodies), web search/crawl (query content), and any future MCP server that sends data outbound via encrypted API calls.

---

## Open questions

### 1. Where should content-level inspection happen?

Options:

- **ContextForge** — inspect tool-call arguments (e.g., `to`, `cc`, `bcc`, `subject`, `body` fields) before the call reaches the MCP server. Can deny based on argument content (recipient allowlist, body content patterns, attachment names).
- **MCP server** — the server itself enforces allowlists or content policies. Requires the server to support this; most don't.
- **Both** — ContextForge for argument-level policy, server for defense-in-depth where supported.

### 2. Recipient allowlists for email send

- Should ContextForge inspect `to`/`cc`/`bcc` arguments and deny if recipients aren't on a pre-approved list?
- Where does the allowlist live — ContextForge config, a separate file, or environment variable?
- How does the operator manage the allowlist (add/remove recipients)?
- What about distribution lists and group addresses that expand to multiple recipients?

### 3. Draft-only mode as an alternative

- Agent composes drafts, operator sends manually. No send capability exposed to the agent at all.
- Eliminates exfiltration risk entirely for email — the operator is the final gate.
- Tradeoff: operator must manually review and send every draft. Doesn't scale if the agent needs to send emails autonomously (e.g., notifications, reminders).
- Is draft-only sufficient for the first guide version, or do we need real send capability?

### 4. Content scanning at the MCP gateway

Beyond recipient allowlists, should ContextForge scan message/attachment content for sensitive data before allowing send?

- Pattern matching (credit cards, API keys, SSNs) — similar to what Pipelock does for egress, but applied to MCP tool arguments.
- DLP-like checks on email body, file upload content, GitHub issue/PR body, etc.
- Is this in scope for the first guide version, or is recipient allowlisting sufficient?

### 5. Generalization across all outbound MCP servers

This isn't just email. Other channels:

- **GitHub** — create public gist, create public repo, push to remote, create issue/PR with sensitive content in body.
- **Google Drive** — share file externally, upload sensitive content, create public link.
- **Chat platforms** — send message to external user, post to public channel.
- **Web search/crawl** — query content itself could contain sensitive data (searching for a secret to find where it's leaked).

Should the first guide version address exfiltration prevention generically (a ContextForge content-inspection framework) or per-server (email first, others later)?

---

## Next steps

- Resolve question 1: where content-level inspection happens (ContextForge, server, or both)
- Resolve question 2: recipient allowlists for email
- Resolve question 3: draft-only mode vs real send capability
- Resolve question 4: content scanning at the MCP gateway
- Resolve question 5: per-server vs generic approach for first guide version
