# Hermes native tools that bypass an out-of-process MCP proxy

An MCP proxy can only intercept tools that Hermes reaches through its **MCP client**. Native Hermes tools are registered and executed inside the same Python process as the agent, so they completely bypass any MCP gateway.

This page inventories every built-in Hermes toolset and maps each to a mitigation: disable it, replace it with an MCP-wrapped equivalent, isolate it via OS-level controls, or accept the residual risk.

Source: [Hermes Built-in Tools Reference](https://hermes-agent.nousresearch.com/docs/reference/tools-reference) (accessed 2026-06-28).

---

## Two tool namespaces in Hermes

1. **Native tools** — live in `hermes-agent`'s in-process registry. Names are flat (e.g., `terminal`, `read_file`). These are the subject of this page.
2. **MCP tools** — loaded from stdio/HTTP MCP servers and prefixed `mcp_<server>_` (e.g., `mcp_github_create_issue`). These are the only tools an out-of-process proxy can see.

If the goal is to put tool-level policy enforcement *outside* the agent, native tools must either disappear from the toolset or run outside the agent process.

---

## Inventory and mitigations

| Toolset                       | Native tools (count)                                                                                                                                                                       | Blast-radius class                                                  | Can MCP proxy intercept? | Mitigation options                                                                                                                             |
|-------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------|---------------------------------------------------------------------|--------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| `terminal`                    | `terminal`, `process` (2)                                                                                                                                                                  | **Critical** — arbitrary shell as Hermes user                       | No                       | Disable; or set `terminal.backend: docker`/`ssh`/`daytona`/`modal` so execution leaves the agent process.                                      |
| `code_execution`              | `execute_code` (1)                                                                                                                                                                         | **Critical** — arbitrary Python in-process, can call tools directly | No                       | Disable entirely; or force a sandboxed/remote backend. Not a security boundary by itself (see issue #4146).                                    |
| `file`                        | `read_file`, `write_file`, `patch`, `search_files` (4)                                                                                                                                     | **High** — arbitrary file R/W                                       | No                       | Disable native file tools; mount `/workspace` read-only where possible; replace with an MCP filesystem server running under a restricted user. |
| `browser`                     | `browser_navigate`, `browser_click`, `browser_type`, `browser_scroll`, `browser_press`, `browser_snapshot`, `browser_vision`, `browser_back`, `browser_console`, `browser_get_images` (10) | **High** — web egress, authenticated sessions, downloads            | No                       | Disable; or route browser traffic through a sandboxed browser MCP server / remote browserless instance; force a no-credential browser profile. |
| `browser` (CDP-gated)         | `browser_cdp`, `browser_dialog` (2)                                                                                                                                                        | **Critical** — raw CDP commands                                     | No                       | Disable; do not expose a CDP endpoint to the agent.                                                                                            |
| `web`                         | `web_search`, `web_extract` (2)                                                                                                                                                            | **High** — network egress and external content parsing              | No                       | Disable; replace with an MCP web-search/server-fetch tool that runs out-of-process.                                                            |
| `x_search`                    | `x_search` (1)                                                                                                                                                                             | **High** — network egress + X/Twitter API                           | No                       | Disable; replace with an MCP X/Twitter server if needed.                                                                                       |
| `computer_use`                | `computer_use` (1)                                                                                                                                                                         | **Critical** — desktop control, screenshots, input injection        | No                       | Disable; requires `cua-driver` on `$PATH`; do not install it in the hardened container.                                                        |
| `image_gen`                   | `image_generate` (1)                                                                                                                                                                       | **Medium** — network egress to image providers, cost                | No                       | Disable; replace with an MCP image-generation server if needed.                                                                                |
| `video` / `video_gen`         | `video_analyze`, `video_generate` (2)                                                                                                                                                      | **Medium** — network egress, cost, large file handling              | No                       | Disable; replace with MCP video-generation/analysis servers if needed.                                                                         |
| `vision`                      | `vision_analyze` (1)                                                                                                                                                                       | **Low–Medium** — image analysis, may use external vision model      | No                       | Disable if not needed; replace with MCP vision server or process only local images.                                                            |
| `tts`                         | `text_to_speech` (1)                                                                                                                                                                       | **Low–Medium** — network egress/cost if cloud TTS                   | No                       | Disable; replace with MCP TTS server if needed.                                                                                                |
| `messaging`                   | `send_message` (1)                                                                                                                                                                         | **High** — outbound messages to any connected platform              | No                       | Disable; replace with a per-platform MCP messaging server that has a narrow allowlist.                                                         |
| `discord` / `discord_admin`   | `discord`, `discord_admin` (2)                                                                                                                                                             | **High** — server read/write, moderation                            | No                       | Disable; replace with an MCP Discord server scoped to one channel if needed.                                                                   |
| `homeassistant`               | `ha_call_service`, `ha_get_state`, `ha_list_entities`, `ha_list_services` (4)                                                                                                              | **High** — physical device control                                  | No                       | Disable; replace with a minimal MCP Home Assistant server exposing only safe domains.                                                          |
| `spotify`                     | `spotify_playback`, `spotify_devices`, `spotify_queue`, `spotify_search`, `spotify_playlists`, `spotify_albums`, `spotify_library` (7)                                                     | **Low** — media control and PII                                     | No                       | Disable; replace with an MCP Spotify server if needed.                                                                                         |
| `delegation`                  | `delegate_task` (1)                                                                                                                                                                        | **High** — spawns subagents with their own toolsets                 | No                       | Disable; or confine subagents to a separate locked-down profile/container.                                                                     |
| `cronjob`                     | `cronjob` (1)                                                                                                                                                                              | **High** — schedules future autonomous runs                         | No                       | Disable; persistence/scheduled work should be orchestrated outside the agent.                                                                  |
| `skills`                      | `skill_view`, `skill_manage`, `skills_list` (3)                                                                                                                                            | **High** — create/modify executable procedural memory               | No                       | Disable `skill_manage`; allow read-only skill viewing if skills are audited before install.                                                    |
| `kanban`                      | `kanban_show`, `kanban_list`, `kanban_complete`, `kanban_block`, `kanban_heartbeat`, `kanban_comment`, `kanban_create`, `kanban_link`, `kanban_unblock` (9)                                | **Medium** — multi-agent orchestration, autonomous task creation    | No                       | Disable the `kanban` toolset unless multi-agent workflow is explicitly required and isolated.                                                  |
| `feishu_doc` / `feishu_drive` | `feishu_doc_read`, `feishu_drive_add_comment`, `feishu_drive_list_comments`, `feishu_drive_list_comment_replies`, `feishu_drive_reply_comment` (5)                                         | **Medium** — enterprise document access                             | No                       | Disable; replace with MCP Feishu/Lark server if needed.                                                                                        |
| `hermes-yuanbao`              | `yb_query_group_info`, `yb_query_group_members`, `yb_send_dm`, `yb_search_sticker`, `yb_send_sticker` (5)                                                                                  | **Medium** — messaging/group info                                   | No                       | Disable; not relevant unless running the Yuanbao platform.                                                                                     |
| `memory`                      | `memory` (1)                                                                                                                                                                               | **Low** — local memory write, but poisonable                        | No                       | Keep if memory content is scanned on write; risk is prompt-injection persistence, not host compromise.                                         |
| `todo`                        | `todo` (1)                                                                                                                                                                                 | **Low** — session task list                                         | No                       | Generally safe; can be disabled if not needed.                                                                                                 |
| `clarify`                     | `clarify` (1)                                                                                                                                                                              | **Low** — asks the user a question                                  | No                       | Generally safe; keep for HITL-style clarification.                                                                                             |
| `session_search`              | `session_search` (1)                                                                                                                                                                       | **Low** — searches local session DB                                 | No                       | Generally safe; disable if session history is sensitive.                                                                                       |

**Totals:** ~71 built-in tools across 29 logical toolsets. The toolsets in the **Critical** and **High** classes (about 42 tools) are the ones that must be removed or relocated before an MCP proxy becomes the meaningful enforcement point.

---

## MCP replacements to investigate

Not every native tool has a drop-in MCP server, but the common high-risk ones do. Candidates to evaluate:

| Native capability | Candidate MCP replacement(s)                                                                         | Notes                                                                         |
|-------------------|------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| Filesystem        | `@modelcontextprotocol/server-filesystem`, `filesSystem`-style servers                               | Must be run under a restricted UID with a read-only or workspace-scoped root. |
| Terminal/shell    | Custom containerized shell MCP server, `mcp-server-shell` variants, or `execute_code` remote backend | Use one-shot containers; no persistent shell across calls.                    |
| Web search        | Brave, Tavily, Firecrawl, Exa, SerpAPI MCP servers                                                   | Route through egress proxy; keep API keys out of the agent.                   |
| Web fetch/extract | Firecrawl, `fetch`-style MCP servers                                                                 | Good for limiting which domains can be reached.                               |
| Browser           | Browserless, Playwright MCP server, Browserbase                                                      | Runs in separate container; discard profile after each task.                  |
| GitHub            | `github` MCP server (official)                                                                       | Good for read-only or scoped-write automation.                                |
| Email / messaging | Per-provider MCP servers (Gmail, Slack, Telegram, Discord)                                           | Easier to scope than the generic `send_message`.                              |
| Image generation  | DALL·E, FAL, Ideogram MCP servers                                                                    | API keys held by proxy or server, not agent.                                  |
| Code execution    | `execute_code` remote container backend, or a sandboxed Python MCP server                            | Must not share the agent's filesystem or network namespace.                   |

---

## Interaction with Hermes toolsets config

Hermes lets you disable toolsets in `config.yaml` or at runtime:

```yaml
toolsets:
  exclude:
    - terminal
    - code_execution
    - file
    - web
    - browser
    - messaging
    - discord
    - discord_admin
    - homeassistant
    - computer_use
    - cronjob
    - delegation
    - skill_manage   # keep skill_view/skills_list if desired
```

At CLI launch:

```bash
hermes chat --toolsets "safe,vision,memory,todo,clarify,session_search"
```

The `safe` toolset is a read-only bundle in Hermes; it is useful for reducing risk but is still in-process and therefore not a security boundary.

---

## Recommended hardening sequence

1. **Start from a minimal toolset.** Launch Hermes with only low-risk toolsets (`safe`, `memory`, `todo`, `clarify`, `session_search`, plus any MCP servers).
2. **Add MCP-wrapped equivalents** for capabilities the agent actually needs.
3. **Disable the native high-risk toolsets** listed above rather than relying on `tools.exclude` alone; excluded tools can be re-enabled by a compromised agent if it can edit config.
4. **Mount `config.yaml` read-only** from the host so the agent cannot re-add native toolsets (already done in the hardened container guide).
5. **Pair with OS-level controls:** read-only rootfs, Landlock/AppArmor for `/workspace`, no network egress except via the MCP proxy/egress proxy, and `terminal`/`execute_code` removed entirely.

---

## Implications for the policy proxy

- An MCP proxy is **not enough** by itself. The first design task is deciding which native toolsets to disable and how to replace them.
- `terminal` and `execute_code` are the biggest bypasses. If they remain, the agent can simply shell out around any MCP proxy.
- The filesystem tools are the next biggest concern, because even a well-intentioned agent can overwrite code, configs, or secrets in `~/.hermes`.
- A practical policy-proxy deployment is therefore a **bundle**: an MCP proxy for policy/audit plus a stripped Hermes toolset plus container/OS isolation for the few capabilities that cannot be moved to MCP.

---

## Sources

- Hermes Agent docs: [Built-in Tools Reference](https://hermes-agent.nousresearch.com/docs/reference/tools-reference)
- Hermes Agent docs: [Toolsets Reference](https://hermes-agent.nousresearch.com/docs/reference/toolsets-reference)
- Hermes Agent docs: [Code Execution](https://hermes-agent.nousresearch.com/docs/user-guide/features/code-execution)
- Hermes Agent docs: [MCP Integration](https://hermes-agent.nousresearch.com/docs/user-guide/features/mcp)
- GitHub issue #4146: `execute_code` sandbox `terminal()` RPC stub
- GitHub issue #41: "Unrestricted Code Execution in `execute_code` Tool"
