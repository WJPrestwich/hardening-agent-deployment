# MCP server selection: File Systems (Glama #25)

Replaces: Hermes `read_file`, `write_file`, `patch`, `search_files` (4 tools).

**Reconsidered category.** Previously picked `@modelcontextprotocol/server-filesystem`; user wants to investigate further. No selection from the top 10 — this will require further thought elsewhere.

---

## Top 10 from Glama (sorted by GitHub stars)

| # | Server | Author | Stars | License | Assessment |
|---|--------|--------|-------|---------|------------|
| 1 | Filesystem MCP Server | `modelcontextprotocol` | 87,454¹ | MIT | Official reference. Previously picked; now under reconsideration. |
| 2 | Google Drive server | `modelcontextprotocol` | 87,454¹ | MIT | Not a local filesystem server. |
| 3 | GitHub MCP Server | `modelcontextprotocol` | 87,454¹ | MIT | Not a local filesystem server. Already picked for GitHub. |
| 4 | Claude Desktop Commander | `wonderwhy-er` | 6,214 | MIT | Terminal + file editing. Overlaps with llm-sandbox. |
| 5 | Desktop Commander MCP | `wonderwhy-er` | 6,214 | MIT | Same as #4, second listing. |
| 6 | MCP server for Obsidian | `MarkusPfundstein` | 3,981 | MIT | Redundant — covered by Obsidian picks. |
| 7 | Excel MCP Server | `haris-musa` | 3,947 | MIT | Excel-specific, not a general filesystem server. |
| 8 | autoMate | `yuruotong1` | 3,926 | MIT | All-in-one. |
| 9 | Markdownify MCP | `zcaceres` | 2,756 | MIT | File conversion, not filesystem access. |
| 10 | Deskaid | `ezyang` | 1,611 | Apache 2.0 | Read/write/edit local files. |

¹ Shared parent repo star count.

---

## Decisions

No selection from this category. The filesystem MCP server needs further thought — likely needs to be evaluated in the context of the overall architecture (container isolation, workspace boundaries, ContextForge policy) rather than as a standalone pick.

The official `@modelcontextprotocol/server-filesystem` remains the fallback if no better option emerges.
