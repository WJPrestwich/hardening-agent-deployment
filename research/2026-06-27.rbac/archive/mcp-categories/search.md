# MCP server selection: Search (Glama #2)

Replaces: Hermes `web_search` tool. Also covers web crawl/fetch and Obsidian integration.

---

## Top 10 from Glama (sorted by GitHub stars)

| # | Server | Author | Stars | Downloads/wk | License | Assessment |
|---|--------|--------|-------|-------------|---------|------------|
| 1 | Brave Search MCP Server | `modelcontextprotocol` | 87,454¹ | 30,181 | MIT | Interim pick for web search. |
| 2 | Google Drive server | `modelcontextprotocol` | 87,454¹ | 6,275 | MIT | Maybe. Don't trust Google much, but simpler than self-hosted cloud storage. Not a search engine replacement. |
| 3 | Google Maps MCP Server | `modelcontextprotocol` | 87,454¹ | 11,868 | MIT | Not useful at this point. |
| 4 | Metabase | `metabase` (official) | 47,904 | — | F | **Avoid.** Enterprise solution for teams. Not for personal use. |
| 5 | Karakeep MCP server | `karakeep-app` | 26,356 | 1,086 | AGPL 3.0 | Interesting but low priority. Bookmarks aren't critical right now. |
| 6 | Firecrawl MCP Server | `mendableai` | 6,709 | 177,532 | MIT | **Avoid as a pick.** Used internally by searxng-mcp as tier-1 fetch. |
| 7 | MCP Atlassian | `sooperset` | 5,435 | — | MIT | **Avoid.** Same as #4 — enterprise, not for personal use. |
| 8 | Exa MCP Server | `exa-labs` | 4,637 | 23,333 | MIT | **Avoid.** Brave seems better. |
| 9 | MCP server for Obsidian | `MarkusPfundstein` | 3,981 | 13 | MIT | Uses the Local REST API plugin. Superseded by cyanheads/obsidian-mcp-server which has RBAC. |
| 10 | Zotero MCP | `54yyyu` | 3,945 | 61 | MIT | **Avoid.** Don't use Zotero. |

¹ Shared parent repo (`modelcontextprotocol/servers`) star count.

Also visible outside top 10: Perplexity API MCP (2,312 stars), Tavily MCP (2,146 stars), ArXiv MCP (2,889 stars), Bright Data MCP (2,473 stars).

---

## Investigation criteria

After the initial top-10 review, the following criteria were defined for deeper investigation:

- Self-hostable, no vendor API lock-in (or uses open/free APIs)
- Personal use, not enterprise
- Lightweight, containerizable
- Bonus: relates to SearXNG, Crawl4AI, open-source search tooling
- Bonus: Obsidian CLI integration (not REST plugin)

---

## Deeper dive findings

### Web search: `tadmstr/searxng-mcp` (the clear winner)

| Detail | Value |
|--------|-------|
| Repo | `github.com/tadmstr/searxng-mcp` |
| Stars | 11 |
| Forks | 0 |
| Commits | 126 |
| License | MIT |
| Language | TypeScript |
| npm | `@tadmstr/searxng-mcp` |
| Transport | stdio + HTTP/SSE |
| Latest release | v3.12.0 (Jun 7, 2026) |

This is exactly what the user was planning to build. Private web search MCP: SearXNG metasearch → ML reranking → 4-tier fetch cascade with per-domain learning, Ollama query expansion and synthesis. No cloud APIs.

**Architecture:**
- SearXNG metasearch → ML reranking → 4-tier fetch cascade (Firecrawl → Crawl4AI → raw HTTP → Wayback Machine)
- Optional Ollama query expansion (`qwen3:4b`) and summarization (`qwen3:14b`)
- Valkey/Redis result caching (search 1h, fetch 24h, crawl 6h)
- Per-domain learning: tracks tier success rates over 30-day windows, auto-skips tiers below 30% success
- Kiwix fast path for Wikipedia/StackOverflow/Arch Wiki (offline ZIM archives)
- llms.txt fast path for documentation sites
- Adblocking at both tiers (Puppeteer CDP for Firecrawl, HTTP forward proxy for Crawl4AI/raw)
- robots.txt compliance, honest User-Agent
- SSRF protection (private IP ranges blocked, redirect chains blocked)
- OpenTelemetry + NATS observability (opt-in, zero overhead when unset)
- Docker Compose for minimal and full topologies

**Tools:** `search`, `search_and_fetch`, `search_and_summarize`, `fetch_url`, `crawl_site`, `clear_cache`.

**Security features relevant to our stack:**
- URL allowlist blocks private/internal IP ranges
- Redirect protection prevents SSRF bypass
- No credentials stored or logged
- Input validation at startup
- `pnpm audit` in CI
- `SECURITY.md`, `CONTRIBUTING.md`, `.gitleaks.toml`

**What it doesn't have (yet):**
- No ProxyRack integration (but Crawl4AI supports proxy config, and the adblock proxy is already pluggable via `ADBLOCK_PROXY_URL`)
- 11 stars — small, but the code is well-structured with CI, security tooling, and a real homelab deployment behind it

**User may contribute to this project.**

### Web crawl/fetch: `unclecode/crawl4ai` (native MCP support)

| Detail | Value |
|--------|-------|
| Repo | `github.com/unclecode/crawl4ai` |
| Stars | 70k |
| Forks | 7.2k |
| Commits | 1,536 |
| License | Apache 2.0 |
| Language | Python |
| Docker | `unclecode/crawl4ai:latest` |
| Latest version | v0.9.x |

Crawl4AI is the #1 trending open-source web crawler on GitHub. It now has native MCP support, exposing `md`, `html`, `screenshot`, `pdf`, `execute_js`, `crawl`, `ask` tools via `ws://localhost:11235/mcp/ws`.

**Key points:**
- Clean Markdown generation with BM25-based content filtering
- Structured data extraction (CSS/XPath/LLM-based)
- Browser pooling, session management, proxy support, stealth mode
- v0.9 made the Docker server secure-by-default: auth on by default, loopback bind, request body as untrusted trust boundary, CORS deny-by-default
- v0.8.7 fixed critical Docker API vulnerabilities (RCE, SSRF, auth bypass, file write, XSS, hardcoded JWT secret)
- Monitoring dashboard, playground, multi-architecture support

**Relevance:** searxng-mcp already uses Crawl4AI as tier-2 fetch. Running Crawl4AI separately also gives the agent direct crawl/fetch capabilities via its native MCP endpoint.

### Obsidian CLI: `kepano/obsidian-skills` (skills, not MCP)

| Detail | Value |
|--------|-------|
| Repo | `github.com/kepano/obsidian-skills` |
| Stars | 38.7k |
| Forks | 2.7k |
| Commits | 46 |
| License | MIT |
| Author | kepano (Steph Ango, Obsidian's creator) |

Agent skills for Obsidian. Follows the Agent Skills specification (`agentskills.io`) — works with Claude Code, Codex, and OpenCode (explicitly documented).

**Skills included:**
- `obsidian-markdown` — Obsidian Flavored Markdown (wikilinks, embeds, callouts, properties)
- `obsidian-bases` — Obsidian Bases (`.base` files with views, filters, formulas)
- `json-canvas` — JSON Canvas (`.canvas` files)
- `obsidian-cli` — Obsidian CLI interaction (vault operations, plugin/theme development)
- `defuddle` — clean markdown extraction from web pages using Defuddle

**OpenCode install:** `git clone https://github.com/kepano/obsidian-skills.git ~/.opencode/skills/obsidian-skills`

This is the right approach for Obsidian CLI integration. Skills teach the agent how to use the CLI directly; the MCP server handles vault operations that need structured tool calls.

### Obsidian vault RBAC: `cyanheads/obsidian-mcp-server`

| Detail | Value |
|--------|-------|
| Repo | `github.com/cyanheads/obsidian-mcp-server` |
| Stars | 609 |
| Forks | 92 |
| Commits | 264 |
| License | Apache 2.0 |
| Language | TypeScript (Bun/Node) |
| Latest release | v3.2.8 (Jun 20, 2026) |
| Docker | `ghcr.io/cyanheads/obsidian-mcp-server` |

14 tools grouped by shape — readers, writers, managers, and a guarded command-palette escape hatch.

**RBAC features (the key reason to use this):**
- `OBSIDIAN_READ_PATHS` — comma-separated folder allowlist for reads (prefix-based, recursive, case-insensitive)
- `OBSIDIAN_WRITE_PATHS` — comma-separated folder allowlist for writes
- `OBSIDIAN_READ_ONLY=true` — global kill switch, disables all write tools from `tools/list`
- `OBSIDIAN_ENABLE_COMMANDS=true` — opt-in for command-palette execution (off by default)
- Write paths are implicitly readable
- Search results filtered against read paths silently
- Denies are typed `path_forbidden` with the active scope echoed back for LLM self-correction
- HTTP transport supports JWT and OAuth auth modes
- `MCP_AUTH_MODE=jwt` with `MCP_AUTH_SECRET_KEY` for non-local deployments

**Interface:** Uses the Obsidian Local REST API plugin (not the CLI). Requires the community plugin installed and enabled in the vault.

**Tools:** `get_note`, `list_notes`, `list_tags`, `search_notes`, `write_note`, `append_to_note`, `patch_note`, `replace_in_note`, `manage_frontmatter`, `manage_tags`, `delete_note`, `open_in_ui`, `list_commands`, `execute_command`.

**Search modes:** `text` (substring with context), `jsonlogic` (JSONLogic tree against path/content/frontmatter/tags/stat), `omnisearch` (BM25-ranked via Omnisearch plugin).

**Destructive operations:** `delete_note` uses `ctx.elicit` for human confirmation when the client supports it. `destructiveHint` annotation surfaces the operation in the host's approval flow otherwise.

### Other SearXNG MCP servers found (not selected)

| Server | Notes |
|--------|-------|
| `aeon-seraph/searxng-mcp` (PyPI) | Production-grade, Eunomia policies, OIDC, OTel. Most feature-complete but heavier than tadmstr. |
| `ihor-sokoliuk/mcp-searxng` (npm) | ~49 stars. Two tools. Simple. |
| `tisDDM/searxng-mcp` | Deprecated in favor of searxNcrawl. |
| `OvertliDS/mcp-searxng-enhanced` | ~52 stars. Category-aware + scraping. |

### No-API-key search MCP servers (not selected)

| Server | Notes |
|--------|-------|
| `yokingma/one-search-mcp` | Multi-provider including SearXNG + DuckDuckGo. Also has local browser automation mode. |
| `mrkrsl/web-search-mcp` | ~972 stars. No API keys. Multi-engine. Playwright-based. |
| `pskill9/web-search` | Scrapes Google directly. Vulnerable to rate limiting. |

---

## Synthesis

The two Obsidian picks are complementary: skills teach the agent *how* to use the CLI and file formats, while the MCP server provides *structured, RBAC-controlled* vault operations. Both can coexist — the skills handle CLI-level tasks (plugin dev, vault management) and the MCP server handles note CRUD with path-scoped permissions.

---

## Decisions

| Capability | Pick | Type | Status |
|-----------|------|------|--------|
| Web search + fetch cascade | `tadmstr/searxng-mcp` | MCP server | **Selected.** Exactly what user planned to build. May contribute upstream. |
| Web crawl/fetch (direct agent access) | `unclecode/crawl4ai` (native MCP) | MCP server | **Selected.** Already used by searxng-mcp as tier-2; also gives agent direct crawl capabilities. |
| Obsidian CLI usage | `kepano/obsidian-skills` | Skills package | **Selected.** Made by Obsidian's creator. Works with OpenCode. |
| Obsidian vault RBAC | `cyanheads/obsidian-mcp-server` | MCP server | **Selected.** Folder-scoped read/write permissions, read-only kill switch, JWT/OAuth auth. No custom RBAC code needed. |
| Web search (interim, if searxng-mcp not yet deployed) | `modelcontextprotocol/brave-search` | MCP server | Fallback only. |

Brave Search is no longer the primary pick — `tadmstr/searxng-mcp` is. Brave becomes a fallback only if searxng-mcp is not yet deployed.

---

## Next steps

- Deploy SearXNG + Firecrawl + Crawl4AI + searxng-mcp as a Docker stack
- Add ProxyRack proxy integration to searxng-mcp (may require contribution upstream)
- Install `kepano/obsidian-skills` into OpenCode skills directory
- Deploy `cyanheads/obsidian-mcp-server` with the Obsidian Local REST API plugin, configured with `OBSIDIAN_READ_PATHS` and `OBSIDIAN_WRITE_PATHS` for vault-scoped access
- Front all MCP servers with ContextForge for tool-level policy
