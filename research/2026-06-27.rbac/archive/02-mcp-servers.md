# B. MCP server security model

- The MCP specification itself **does not enforce** per-invocation consent or
  tool restrictions; it delegates enforcement to the host/client.
- Hermes/native clients can use `enabled_tools` / `disabled_tools` /
  `default_tools_approval_mode` and per-tool `approval_mode`.
- Reference servers map OAuth scopes or PAT scope headers to exposed tools:
  GitHub filters by `X-OAuth-Scopes`; Slack uses OAuth scopes such as
  `mcp:connect`, `chat:write`, `channels:read`; Google Drive servers request
  Drive/Docs/Sheets scopes; email servers can be made read-only by omitting
  SMTP config.
- stdio transport relies on local host security; HTTP/SSE transport needs TLS,
  short-lived audience-bound tokens, mTLS, and careful header handling (proxies
  may strip or forward headers).
- Practical recommendation for our stack: keep MCP servers local/stdio, wrap
  them with `pipelock mcp proxy`, and enforce allow/deny lists in the client
  config.

## Sources

- modelcontextprotocol.io specification and authorization tutorial
- OpenAI Codex MCP docs
- GitHub blog: OAuth scope filtering for GitHub MCP Server
- Slack MCP security blog
- Google Drive MCP reference implementation
- ai-zerolab/mcp-email-server
- Bifrost MCP connecting docs
- Backslash security blog on MCP attack surfaces
