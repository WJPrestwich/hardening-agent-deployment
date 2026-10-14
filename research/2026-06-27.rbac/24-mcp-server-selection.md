# MCP server selection targets

This page maps every Hermes native toolset that we plan to disable or replace to specific MCP servers. The goal is to produce a definitive list of MCP servers to deploy in the hardened stack, each fronted by ContextForge for tool-level policy.

**Status:** Draft. Categories marked "decided" have a confirmed pick. Categories marked "candidate" have a leading pick from the Glama category investigation but are not yet finalized.

See [24a-mcp-category-triage.md](./archive/24a-mcp-category-triage.md) for the full Glama category triage and [mcp-categories/](./archive/mcp-categories/) for per-category investigation files.

---

## Decided picks

### Code execution + shell (decided: `llm-sandbox`)

Replaces: `execute_code` (1 tool) + `terminal` / `process` (2 tools).

| Criterion            | Value                                                           |
|----------------------|-----------------------------------------------------------------|
| **Pick**             | **`vndee/llm-sandbox`**                                         |
| Repo                 | `github.com/vndee/llm-sandbox`                                  |
| Stars                | ~1k+                                                            |
| License              | MIT                                                             |
| MCP native           | Yes — built-in `llm_sandbox.mcp_server` module                  |
| Isolation            | Docker / rootless Podman / K8s container                        |
| Network isolation    | `SANDBOX_NETWORK_MODE=none`                                     |
| Filesystem isolation | `SANDBOX_READ_ONLY=true`, `--cap-drop ALL`, `no-new-privileges` |
| Languages            | Python, JS, Java, C++, Go, R, Ruby                              |
| Self-hosted          | Yes (PyPI `llm-sandbox[mcp-docker]` or `[mcp-podman]`)          |

**Why one server for both.** `llm-sandbox` can run both code and shell commands. Using one server instead of two reduces the component count and attack surface. The security knobs (`SANDBOX_NETWORK_MODE=none`, read-only, cap-drop) apply to both modes.

**What we give up vs. a dedicated shell server.** `pottekkat/sandbox-mcp` (~117 stars, Go) has true one-shot container semantics with auto-removal by default and a dedicated `shell` sandbox with no network. `llm-sandbox` can achieve the same with env vars but its default lifecycle is less strictly one-shot. Acceptable tradeoff for simplicity.

**Deployment.** Run as a container on `agentnet`. Configure with `SANDBOX_NETWORK_MODE=none` (or route through Pipelock if network is needed), `SANDBOX_READ_ONLY=true`, `SANDBOX_CAP_DROP=ALL`, `SANDBOX_SECURITY_OPT=no-new-privileges:true`, CPU/memory limits. ContextForge fronts it for per-call policy.

### Web search + fetch (decided: `tadmstr/searxng-mcp`)

Replaces: `web_search`, `web_extract` (2 tools).

| Criterion    | Value                                                                                                |
|--------------|------------------------------------------------------------------------------------------------------|
| **Pick**     | **`tadmstr/searxng-mcp`**                                                                            |
| Repo         | `github.com/tadmstr/searxng-mcp`                                                                     |
| Stars        | 11                                                                                                   |
| License      | MIT                                                                                                  |
| Transport    | stdio + HTTP/SSE                                                                                     |
| Architecture | SearXNG metasearch → ML reranking → 4-tier fetch cascade (Firecrawl → Crawl4AI → raw HTTP → Wayback) |

**Why this over Brave.** Exactly what the user planned to build: SearXNG + Crawl4AI + proxy support, no cloud APIs, self-hosted, per-domain learning, Ollama query expansion/summarization. User may contribute upstream. Brave Search remains a fallback if searxng-mcp is not yet deployed.

See [mcp-categories/search.md](./archive/mcp-categories/search.md) for the full investigation.

### Web crawl/fetch (decided: `unclecode/crawl4ai`)

Replaces: direct crawl/fetch capabilities not covered by searxng-mcp's fetch cascade.

| Criterion    | Value                                         |
|--------------|-----------------------------------------------|
| **Pick**     | **`unclecode/crawl4ai`** (native MCP support) |
| Repo         | `github.com/unclecode/crawl4ai`               |
| Stars        | 70k                                           |
| License      | Apache 2.0                                    |
| MCP endpoint | `ws://localhost:11235/mcp/ws`                 |

Already used by searxng-mcp as tier-2 fetch. Running it separately also gives the agent direct crawl capabilities via its native MCP endpoint (tools: `md`, `html`, `screenshot`, `pdf`, `execute_js`, `crawl`, `ask`).

### Obsidian CLI (decided: `kepano/obsidian-skills`)

Replaces: Obsidian CLI interaction (vault operations, plugin/theme development, file format authoring).

| Criterion | Value                                   |
|-----------|-----------------------------------------|
| **Pick**  | **`kepano/obsidian-skills`**            |
| Repo      | `github.com/kepano/obsidian-skills`     |
| Stars     | 38.7k                                   |
| License   | MIT                                     |
| Type      | Skills package (not an MCP server)      |
| Author    | kepano (Steph Ango, Obsidian's creator) |

Skills: `obsidian-markdown`, `obsidian-bases`, `json-canvas`, `obsidian-cli`, `defuddle`. Follows the Agent Skills specification — works with OpenCode. Install: `git clone https://github.com/kepano/obsidian-skills.git ~/.opencode/skills/obsidian-skills`.

### Obsidian vault RBAC (decided: `cyanheads/obsidian-mcp-server`)

Replaces: structured vault operations (note CRUD, search, tags, frontmatter) with folder-scoped permissions.

| Criterion | Value                                                               |
|-----------|---------------------------------------------------------------------|
| **Pick**  | **`cyanheads/obsidian-mcp-server`**                                 |
| Repo      | `github.com/cyanheads/obsidian-mcp-server`                          |
| Stars     | 609                                                                 |
| License   | Apache 2.0                                                          |
| Transport | stdio + Streamable HTTP                                             |
| RBAC      | `OBSIDIAN_READ_PATHS`, `OBSIDIAN_WRITE_PATHS`, `OBSIDIAN_READ_ONLY` |

14 tools with folder-scoped read/write permissions, search (text/JSONLogic/Omnisearch), JWT/OAuth auth modes. Uses the Obsidian Local REST API plugin. Complementary to the skills package — skills handle CLI/format tasks, MCP server handles structured vault operations with RBAC.

### GitHub (decided: `github/github-mcp-server`)

Replaces: GitHub operations previously done via `terminal` or `execute_code`.

| Criterion      | Value                                                                                                           |
|----------------|-----------------------------------------------------------------------------------------------------------------|
| **Pick**       | **`github/github-mcp-server`**                                                                                  |
| Repo           | `github.com/github/github-mcp-server`                                                                           |
| Stars          | ~24.4k                                                                                                          |
| License        | MIT                                                                                                             |
| Classification | Official (GitHub)                                                                                               |
| Transport      | stdio (local Docker/binary) + HTTP (hosted at `api.githubcopilot.com/mcp/`)                                     |
| Scoped access  | `--toolsets` flag, `GITHUB_READ_ONLY=1`, `X-MCP-Readonly` header, `X-MCP-Lockdown` header, `--gh-host` for GHES |

**Security notes.** Use a fine-grained PAT scoped to specific repos + `GITHUB_READ_ONLY=1` for a hardened setup. Run via the official Docker image (`ghcr.io/github/github-mcp-server`) with the token injected via env.

### Filesystem (decided: `rust-mcp-stack/rust-mcp-filesystem`) — DEFERRED

**Status:** Deferred to a future guide version to reduce complexity. Hermes' native file tools stay enabled in v1 (in-process, container-scoped). The pick and deployment design below are preserved for when the server is reinstated. See [25-research-summary.md](./25-research-summary.md) §3.11 and §6.3.

Replaces: `read_file`, `write_file`, `patch`, `search_files` (4 tools).

| Criterion      | Value                                                                   |
|----------------|-------------------------------------------------------------------------|
| **Pick**        | **`rust-mcp-stack/rust-mcp-filesystem`**                                |
| Repo           | `github.com/rust-mcp-stack/rust-mcp-filesystem`                         |
| Stars          | 159                                                                     |
| Forks          | 28                                                                      |
| Commits        | 129                                                                     |
| Releases       | 28 (latest May 2026)                                                    |
| License        | MIT                                                                     |
| Language       | Rust (single static binary, no runtime dependencies)                    |
| Transport      | stdio                                                                   |
| Install        | `cargo install`, `brew`, `npm`, shell script, or Docker                 |
| Docker         | Yes (Docker Hub MCP registry)                                           |
| Read-only      | **Yes by default** — starts with no write access until explicitly configured |
| Tool disabling | Yes — disable specific tools to save tokens and reduce attack surface   |
| MCP Roots      | Yes (opt-in, disabled by default)                                       |
| Security       | Path confinement, directory traversal protection, advanced glob search  |
| Extra tools    | ZIP archive create/extract, content search, copy, delete — beyond what the official server offers |

**Why this over the official `@modelcontextprotocol/server-filesystem`.** Read-only by default (strongest security posture), single Rust binary with no runtime dependencies (no Node.js/npm supply chain), tool disabling to reduce attack surface, ZIP support, most actively released (28 releases), and a superset of the official server's tools.

**Why this over `mark3labs/mcp-filesystem-server`.** The Go server has more stars (661 vs 159) but hasn't released since June 2025. The Rust server is more actively maintained, has read-only-by-default, tool disabling, MCP Roots support, and ZIP support.

**RBAC interaction.** ContextForge will front this server for per-tool/per-argument policy. The server's own read-only-by-default and path confinement provide defense-in-depth below the ContextForge layer.

### Email + Google Workspace (decided: `taylorwilsdon/google_workspace_mcp`) — DEFERRED

**Status:** Email is out of scope for this guide update. The pick is preserved for future resolution.

Replaces: `send_message` (email channel), plus any IMAP/SMTP usage via `terminal`/`execute_code`. Also covers Google Calendar, Drive, Docs, Sheets, Slides, Forms, Tasks, Contacts, Chat, and Search — subsuming the Google Calendar candidate.

| Criterion      | Value                                                                                           |
|----------------|-------------------------------------------------------------------------------------------------|
| **Pick**       | **`taylorwilsdon/google_workspace_mcp`**                                                        |
| Repo           | `github.com/taylorwilsdon/google_workspace_mcp`                                                 |
| Stars          | 2,8k                                                                                            |
| Forks          | 844                                                                                             |
| Commits        | 2,445                                                                                           |
| License        | MIT                                                                                             |
| Language       | Python 3.10+                                                                                    |
| PyPI           | `workspace-mcp`                                                                                 |
| Transport      | stdio + streamable HTTP                                                                         |
| Services       | Gmail, Drive, Calendar, Docs, Sheets, Slides, Forms, Tasks, Contacts, Chat, Apps Script, Search |
| Auth           | OAuth 2.0 & 2.1, auto token refresh, multi-user bearer tokens, PKCE                             |
| Read-only mode | `--read-only` requests only `*.readonly` scopes and filters write tools                         |
| Granular perms | `--permissions gmail:send drive:readonly` per-service scope control                             |
| Tool tiers     | `core`, `extended`, `complete` — cumulative, selective service loading                          |
| Stateless mode | `WORKSPACE_MCP_STATELESS_MODE=true` for container environments                                  |
| Docker         | Yes (`Dockerfile`, `docker-compose.yml`)                                                        |

**Security features.** No telemetry, no usage reporting, no SaaS dependency. Data path is: your infrastructure → Google APIs. Your OAuth client, your GCP project. Credentials never leave your environment. Sensitive path blocking (`~/.ssh/`, `~/.aws/`, `.env*`). Stateless mode for locked-down containers. Supports reverse proxy deployment.

**Why this over `klemensgc/mcp-google`.** Far more feature-complete (12 services vs 6), actively maintained (2,445 commits), MIT licensed (not F), proper OAuth 2.1 with PKCE, tool tiers for progressive access, granular per-service permissions (`gmail:send`, `drive:readonly`), read-only mode, stateless container mode, and a full CLI. This is the most comprehensive Google Workspace MCP server available.

**RBAC design questions remain.** How to enforce read-only-by-default with send as an elevated capability, how to gate send behind ContextForge approval, how to prevent exfiltration via email, how to scope OAuth tokens — see [25-research-summary.md](./25-research-summary.md) §6.2, [mcp-categories/email.md](./archive/mcp-categories/email.md), and [03-email.md](./archive/03-email.md).

**Subsumes Google Calendar.** This server covers Google Calendar natively, so the separate `nspady/google-calendar-mcp` candidate is no longer needed.

---

## Watchlist (future phases)

| Capability                 | Candidate                                                                                                                                | When to revisit                |
|----------------------------|------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------|
| Cross-platform memory      | `topoteretes/cognee`                                                                                                                     | Cross-platform memory priority |
| Codebase intelligence      | `DeusData/codebase-memory-mcp`                                                                                                           | Hermes used for development    |
| Temporal knowledge graph   | `getzep/graphiti`                                                                                                                        | Temporal knowledge needed      |
| Phone/voice                | `fonoster/fonoster`                                                                                                                      | Out of scope for first push    |
| Task management (TickTick) | Custom MCP server based on `dev-mirzabicer/ticktick-sdk`. All existing TickTick MCP servers have unaddressed issues; will build our own. | After first guide phase        |
| Notion                     | `makenotion/notion-mcp-server` (MIT, 4.5k stars)                                                                                         | Out of scope for first phase   |
| Google NotebookLM          | `jacob-bd/notebooklm-mcp-cli` (MIT, 5.1k stars)                                                                                          | Out of scope for first phase   |
| E-book interaction         | `onebirdrocks/ebook-mcp` (Apache 2.0, 368 stars)                                                                                         | Out of scope for first phase   |
| Flashcard study            | `ankimcp/anki-mcp-server` (MIT, 334 stars)                                                                                               | Out of scope for first phase   |

See [mcp-categories/knowledge-and-memory.md](./archive/mcp-categories/knowledge-and-memory.md).

---

## Deferred capabilities

No MCP server needed for the first guide version. These Hermes native tools will simply be disabled.

- Browser automation — not implementing at this time
- Video generation/analysis
- TTS
- Vision/image analysis (except structured data extraction from images)
- X/Twitter search
- Spotify
- Feishu/Lark
- Kanban/multi-agent orchestration
- Image generation
- Entertainment & media
- Games & gamification

---

## Capabilities that may not need an MCP server

- Cronjob/scheduling — orchestrate outside the agent
- Subagent delegation — confine to a separate container
- Memory — low-risk local write, keep Hermes native
- Skills management — disable `skill_manage`, may keep `skill_view`/`skills_list` native
- Todo, clarify, session_search — low-risk, keep native

---

## Sources

- `modelcontextprotocol/servers` GitHub repository
- `vndee/llm-sandbox` GitHub and PyPI
- `pottekkat/sandbox-mcp` GitHub
- `tadmstr/searxng-mcp` GitHub
- `unclecode/crawl4ai` GitHub
- `kepano/obsidian-skills` GitHub
- `cyanheads/obsidian-mcp-server` GitHub
- `github/github-mcp-server` GitHub
- `taylorwilsdon/google_workspace_mcp` GitHub
- `nspady/google-calendar-mcp` GitHub (subsumed by google_workspace_mcp)
- `fonoster/fonoster` GitHub
- `eyaltoledano/claude-task-master` GitHub
- `makenotion/notion-mcp-server` GitHub
- `jacob-bd/notebooklm-mcp-cli` GitHub
- `onebirdrocks/ebook-mcp` GitHub
- `ankimcp/anki-mcp-server` GitHub
- `rust-mcp-stack/rust-mcp-filesystem` GitHub
- `mark3labs/mcp-filesystem-server` GitHub (compared, not selected)
- `modelcontextprotocol/servers` filesystem (compared, not selected)
- Hermes Agent docs: `terminal.backend` configuration
- GitHub issue #7071: `PYTHONPATH` injection in `execute_code` sandbox
- Glama MCP directory (`glama.ai/mcp`) — category listings sorted by GitHub stars
