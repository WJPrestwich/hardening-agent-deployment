# Proposed guide outline

A new top-level section or page in the hardening guide.

---

1. **Access control overview** — why RBAC alone is not enough; layers of defense.
2. **Hermes-native controls** — Tirith fail-closed, `disabled_toolsets`, Blank Slate mode, skill trust tiers.
3. **MCP server governance** — allow/deny lists, local stdio vs remote HTTP, per-server credentials, ContextForge as the gateway.
4. **Runtime integrity** — disabling `execute_code` and `terminal`, replacing with `llm-sandbox`, plugin/skill audit.
5. **Web search and crawl** — `searxng-mcp` + `crawl4ai` deployment, egress routing through Pipelock.
6. **Obsidian integration** — `kepano/obsidian-skills` + `cyanheads/obsidian-mcp-server` with path-scoped RBAC.
7. **Email hardening** — Gmail OAuth scopes, `mcp-google` config, approval-gated send, recipient allowlists.
8. **Credential scoping** — no broker; tightly scoped static credentials, provider-side rotation, compensating controls.
9. **Resource and rate limits** — cgroup v2 limits, per-tool and daily send quotas via ContextForge.
10. **Human-in-the-loop** — sync vs async approval, platform UX patterns, audit fields (stub — parked).
11. **Generated code scanning** — LlamaFirewall CodeShield container, `POST /scan/code` integration.
12. **Verification checklist** — prove each layer is enforced.
