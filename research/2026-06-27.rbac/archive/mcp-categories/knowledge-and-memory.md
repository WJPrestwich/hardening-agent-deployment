# MCP server selection: Knowledge & Memory (Glama #9)

Replaces: Hermes `memory` tool.

---

## Top 10 from Glama (sorted by GitHub stars)

| # | Server | Author | Stars | License | Assessment |
|---|--------|--------|-------|---------|------------|
| 1 | Knowledge Graph Memory Server | `modelcontextprotocol` | 87,454¹ | MIT | **Avoid.** Hermes already has memory; this doesn't add much. |
| 2 | Graphiti MCP Server | `getzep` | 28,062 | Apache 2.0 | **Watchlist.** Temporal knowledge graph. Powerful — keep in mind. |
| 3 | cognee-mcp | `topoteretes` | 23,761 | Apache 2.0 | **Watchlist.** Cross-platform consistent memory. User uses many platforms. |
| 4 | codebase-memory-mcp | `DeusData` | 18,914 | MIT | **Watchlist.** Code intelligence knowledge graph. "Possibly massive" for development use. |
| 5 | Context Mode | `mksglu` | 18,277 | Elastic 2.0 | Interesting, not first phase. |
| 6 | TxtAI MCP Server | `neuml` | 12,676 | Apache 2.0 | **Avoid.** Duplicate functionality. |
| 7 | notebooklm-mcp | `jacob-bd` | 5,060 | MIT | Might be useful, not first phase. |
| 8 | RyanNg (Cipher) | `campfirein` | 4,856 | Elastic 2.0 | **Avoid.** More duplicates. |
| 9 | autoMate | `yuruotong1` | 3,926 | MIT | **Avoid.** Wary of all-in-one solutions. |
| 10 | CodeGraphContext | `Shashankss1205` | 3,816 | MIT | Possibly useful for development work. |

¹ Shared parent repo star count.

## Notable beyond top 10

| Server | Stars | License | Notes |
|--------|-------|---------|-------|
| basic-memory | 3,322 | AGPL 3.0 | Stores knowledge in Markdown files, integrates directly with Obsidian. |
| MCP Memory Service | 1,911 | Apache 2.0 | ChromaDB + sentence transformers. |

---

## Decisions

| Capability | Pick | Status |
|-----------|------|--------|
| Basic persistent memory | Keep Hermes native `memory` tool | Decided |
| Note-taking / knowledge management | Covered by Obsidian picks (see [search.md](./search.md)) | Decided |
| Cross-platform consistent memory | `topoteretes/cognee` | **Watchlist** — investigate when cross-platform memory becomes a priority |
| Codebase intelligence | `DeusData/codebase-memory-mcp` | **Watchlist** — strong candidate when Hermes is used for development |
| Temporal knowledge graph | `getzep/graphiti` | **Watchlist** — keep in mind for future use |

No first-phase MCP server selection for this category.
