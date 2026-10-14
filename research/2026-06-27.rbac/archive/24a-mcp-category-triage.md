# MCP server category triage

Mapping of Glama MCP server categories to Hermes toolset replacements and deployment priorities. This is the working document that feeds into [24-mcp-server-selection.md](./24-mcp-server-selection.md).

---

## Don't care / won't implement

| Glama # | Category                  | Reason                                                                                                                         |
|---------|---------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| 19      | Browser Automation        | Not implementing browser automation at this time                                                                               |
| 18      | Government Data           | —                                                                                                                              |
| 24      | Blockchain                | —                                                                                                                              |
| 28      | Image & Video Processing  | Not needed, except vision for extracting structured data from images with graphs/text. Tracked as a narrow sub-need under #37. |
| 31      | Cryptocurrency            | —                                                                                                                              |
| 39      | Social Media              | User doesn't use social media. Covers X/Twitter (`x_search`).                                                                  |
| 42      | Observability             | —                                                                                                                              |
| 45      | OS Automation             | —                                                                                                                              |
| 48      | CRM                       | —                                                                                                                              |
| 54      | API Testing               | —                                                                                                                              |
| 61      | Coding Agents             | —                                                                                                                              |
| 64      | Penetration Testing       | —                                                                                                                              |
| 65      | Customer Support          | —                                                                                                                              |
| 68      | Customer Data Platforms   | —                                                                                                                              |
| 74      | Sports                    | —                                                                                                                              |
| 77      | Real Estate               | —                                                                                                                              |
| 78      | Bioinformatics            | —                                                                                                                              |
| 82      | Product Management        | —                                                                                                                              |
| 83      | Energy                    | —                                                                                                                              |
| 84      | Aerospace & Astrodynamics | —                                                                                                                              |
| 85      | Feature Flags             | —                                                                                                                              |

---

## Decided

| Glama # | Category        | Pick                       | Replaces                            |
|---------|-----------------|----------------------------|-------------------------------------|
| 27      | Code Execution  | `vndee/llm-sandbox`        | `execute_code`                      |
| 35      | Command Line    | `vndee/llm-sandbox`        | `terminal`, `process`               |
| 38      | Version Control | `github/github-mcp-server` | GitHub operations                   |
| 44      | Shell Access    | `vndee/llm-sandbox`        | `terminal`, `process` (same as #35) |

---

## Needs investigation — high priority

These map to existing Hermes toolsets the user wants to replace or are new capabilities the user wants to add.

| Glama # | Category                   | Hermes toolset / new capability                             | Notes                                                                                                                                                                                                                                                                                                                              |
|---------|----------------------------|-------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 2       | Search                     | `web_search`, `web_extract`, `crawl`, Obsidian vault access | **Selected:** `tadmstr/searxng-mcp` (search + fetch cascade), `unclecode/crawl4ai` (direct crawl, native MCP), `kepano/obsidian-skills` (Obsidian CLI skills), `cyanheads/obsidian-mcp-server` (vault RBAC). Fallback: `brave-search` if searxng-mcp not yet deployed. See [mcp-categories/search.md](./mcp-categories/search.md). |
| 9       | Knowledge & Memory         | `memory`                                                    | **First phase:** keep Hermes native `memory` + Obsidian picks. **Watchlist:** cognee (cross-platform memory), codebase-memory-mcp (dev knowledge graph), Graphiti (temporal knowledge graph). See [mcp-categories/knowledge-and-memory.md](./mcp-categories/knowledge-and-memory.md).                                              |
| 12      | Web Scraping               | `web_extract`                                               | **Covered by #2 picks:** `tadmstr/searxng-mcp` (fetch cascade) + `unclecode/crawl4ai` (native MCP crawl). No separate server needed.                                                                                                                                                                                               |
| 16      | Communication              | `send_message`, `discord`, `discord_admin`                  | **Candidate:** `fonoster/fonoster` (phone/voice). See [mcp-categories/communication.md](./mcp-categories/communication.md).                                                                                                                                                                                                        |
| 17      | Project Management         | `kanban_*`                                                  | **Candidates:** `eyaltoledano/claude-task-master` (Taskmaster), `Pimzino/spec-workflow-mcp`, `Storybloq/storybloq`, `cyanheads/atlas-mcp-server`. See [mcp-categories/project-management.md](./mcp-categories/project-management.md).                                                                                              |
| 25      | File Systems               | `read_file`, `write_file`, `patch`, `search_files`          | No selection from top 10. Needs further thought in architectural context. Official `@modelcontextprotocol/server-filesystem` remains fallback. See [mcp-categories/file-systems.md](./mcp-categories/file-systems.md).                                                                                                             |
| 33      | Note Taking                | `memory` (overlap with #9)                                  | **Candidates:** `makenotion/notion-mcp-server`, `jacob-bd/notebooklm-mcp-cli`. Obsidian already covered by Search picks. See [mcp-categories/note-taking.md](./mcp-categories/note-taking.md).                                                                                                                                     |
| 36      | Entertainment & Media      | `spotify_*`                                                 | No candidates selected. See [mcp-categories/entertainment-and-media.md](./mcp-categories/entertainment-and-media.md).                                                                                                                                                                                                              |
| 46      | Education & Learning Tools | New capability                                              | **Candidates:** `onebirdrocks/ebook-mcp`, `ankimcp/anki-mcp-server`. See [mcp-categories/education-and-learning-tools.md](./mcp-categories/education-and-learning-tools.md).                                                                                                                                                       |
| 49      | Games & Gamification       | New capability                                              | No candidates selected. See [mcp-categories/games-and-gamification.md](./mcp-categories/games-and-gamification.md).                                                                                                                                                                                                                |
| 55      | Email                      | email (via `send_message` or `terminal`)                    | **Candidate:** `taylorwilsdon/google_workspace_mcp` (Gmail + 12 Google services, MIT, OAuth 2.1, read-only mode, granular permissions, tool tiers). Subsumes Google Calendar (#58). **Major research line** — RBAC for email needs design work. See [mcp-categories/email.md](./mcp-categories/email.md).                                                                                                  |
| 58      | Calendar Management        | `cronjob`                                                   | **Subsumed by #55:** `taylorwilsdon/google_workspace_mcp` covers Google Calendar natively. See [mcp-categories/calendar-management.md](./mcp-categories/calendar-management.md).                                                                                                                                                      |

---

## Needs investigation — medium priority

These map to existing Hermes toolsets but were not marked as high priority. Kept here so they're not lost.

| Glama # | Category              | Hermes toolset                                                  | Notes                                                                                                                                                          |
|---------|-----------------------|-----------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 37      | Multimedia Processing | `video_*`, `image_generate`, `text_to_speech`, `vision_analyze` | Broad category; includes the narrow use case of vision-based structured data extraction from images (graphs/text) — the only part of #28 the user cares about. |
| 69      | Home Automation & IoT | `ha_*`                                                          | Home Assistant is the choice, but user has nothing to automate right now. Low priority.                                                                        |
| 75      | Speech Processing     | `text_to_speech`                                                | Needs investigation, but later.                                                                                                                                |
| 81      | Text-to-Speech        | `text_to_speech`                                                | Same as #75.                                                                                                                                                   |

---

## All other categories

Not explicitly triaged. Available in the Glama directory if needed later. See [https://glama.ai/mcp/attributes#categories](https://glama.ai/mcp/attributes#categories) for the full list of 86 categories.
