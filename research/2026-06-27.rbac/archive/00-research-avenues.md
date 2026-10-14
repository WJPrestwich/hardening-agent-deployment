# Research avenues

These were the focused questions we sent to Tavily, one per avenue.

## A. Hermes' own security and policy primitives

- How does `Tirith` decide to block a command? Can it be extended with custom
  rules or categories beyond the built-in dangerous-command list?
- What does the `security` block in `config.yaml` support beyond
  `tirith_enabled`, `tirith_fail_open`, `redact_secrets`, and `website_blocklist`?
- Is there a way to allow/deny specific toolsets, skills, or MCP tools in
  `config.yaml` (e.g., `allowed_tools`, `denied_tools`, `allowed_skills`)?
- How do skill trust tiers (`builtin`, `official`, `community`) map to
  permissions, and can the user override them?
- How does Hermes spawn subagents/delegates, and what isolation (if any) exists
  between them?

## B. MCP server security model

- Does the MCP protocol or the reference SDKs provide a mechanism for the
  *client* to restrict which tools a server may expose, or to require consent
  per tool invocation?
- How do official MCP servers (filesystem, git, github, slack, google, etc.)
  handle authentication and scope? Can their credentials be scoped to
  read-only or to specific resources?
- What is the state of MCP server sandboxing (e.g., stdio vs HTTP/SSE,
  capability manifests, permission prompts)?

## C. Email integration options and their least-privilege profiles

- What OAuth scopes do Gmail API and Microsoft Graph expose for mail? Which
  are read-only, send-only, full-access?
- Are there existing MCP servers or Hermes skills for Gmail/Outlook/IMAP? How
  do they authenticate?
- What are the trade-offs between OAuth, app passwords, and IMAP/SMTP plain
  credentials in an agent context?
- Can provider-side controls (Gmail app authorization, Microsoft Conditional
  Access) complement agent-side RBAC?

## D. Existing agent RBAC / authorization patterns

- Are there published patterns for enforcing policy on LLM tool calls
  (OpenAI functions, Anthropic tool use, LangChain/LangGraph agents)?
- How do projects like OPA (Open Policy Agent), Cedar, or SpiceDB apply to
  agent actions?
- Are there open-source "agent guardrails" projects that proxy or intercept
  tool calls for approval/rate-limiting/audit?

## E. Container and host-level MAC for agents

- What is the practical effort to write an AppArmor or SELinux profile that
  restricts the Hermes container to a workspace and known binaries?
- Can Landlock, seccomp-bpf, or user namespaces provide finer filesystem or
  syscall controls without full LSM complexity?
- How do rootless Docker / rootless Podman change the threat model for an
  agent that runs commands and reads files?

## F. Human-in-the-loop and approval workflows

- What patterns exist for "ask the user before sending email" or "ask before
  writing outside the workspace"?
- Can this be done synchronously (block the tool call) or asynchronously
  (queue the action)?
- What UX do messaging gateways (Telegram/Discord/Slack) provide for quick
  approve/deny buttons?

## G. Credential scoping and short-lived tokens

- How can ClawShell (or a custom broker) return a short-lived, scoped token
  instead of the real provider key?
- What provider APIs support scoped keys (OpenAI project keys, Anthropic
  workspace keys, etc.)?
- Could HashiCorp Vault / AWS STS / GCP service-account impersonation be used
  inside the agent stack?

## H. DLP and content filtering beyond HTTP

- How can SMTP/IMAP bodies and attachments be scanned for secrets/PII before
  delivery?
- What open-source proxies exist for SMTP/IMAP egress filtering?
- How does Pipelock's current body-scanning model map to non-HTTP protocols?

## I. Non-RBAC blast-radius controls

- What sandboxing options exist beyond Docker for an agent that runs shell
  commands (gVisor, Kata Containers, Firecracker, rootless Podman, VM)?
- Which of those support GPU passthrough for the vLLM inference path?
- What is the practical state of Landlock and user namespaces for confining
  file access without writing full LSM profiles?
- Are there open-source canary-token / honeypot libraries suitable for
  detecting unauthorized file reads or email sends?
- How can cgroup v2 limits be applied to the Hermes container to cap CPU,
  memory, disk I/O, and network bandwidth?
