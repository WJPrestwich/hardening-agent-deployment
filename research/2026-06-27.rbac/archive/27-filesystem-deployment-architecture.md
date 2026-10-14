# Filesystem deployment architecture — DEFERRED

**Status:** The filesystem MCP server is deferred to a future guide version to reduce complexity (see [25-research-summary.md](./25-research-summary.md) §3.11 and §6.3). Hermes' native file tools stay enabled in v1. This design is preserved for when the server is reinstated.

Addressing [25-research-summary.md](./25-research-summary.md) §3.11.

**Pick:** `rust-mcp-stack/rust-mcp-filesystem` (MIT, 159 stars, Rust single binary, read-only by default, tool disabling, MCP Roots, ZIP support, 28 releases).

---

## Open questions

### 1. How does the server interact with container isolation?

The Hermes container runs with `--cap-drop ALL`, `--read-only` rootfs, and an isolated bridge network. The filesystem MCP server needs to access files the agent reads/writes. Options:

1. **Run inside the Hermes container** — the server has direct access to the same filesystem as the agent. No inter-container communication needed. But a compromised agent can attack the server process directly (same container, same UID).
2. **Run as a separate container with bind mounts** — the server runs in its own container with bind mounts to specific workspace directories. The agent talks to it via ContextForge (stdio or HTTP). A compromised agent cannot attack the server process directly. This is the same pattern used for other MCP servers.
3. **Run as a host-level service** — the server runs on the host, accessible via a Unix socket or HTTP. Maximum isolation from the agent, but the server has host filesystem access (broader than intended).

**Decision:** Option 1 (run inside the Hermes container). Simplest deployment — the server has direct access to the same filesystem as the agent, no inter-container communication needed. ContextForge is still the enforcement boundary between the agent and the server; the agent cannot reach the filesystem server except through ContextForge's tool-call interception. The server's read-only-by-default and path confinement are defense-in-depth below ContextForge. The tradeoff (a compromised agent could attack the server process directly since they share the container) is acceptable because the Hermes container is already treated as an untrusted workload — a compromised agent inside the container is game-over for anything inside it regardless.

### 2. How do ContextForge path policies interact with the server's own path confinement?

The Rust MCP server enforces path confinement via CLI args (allowed directories) and optionally MCP Roots. ContextForge enforces per-tool/per-argument policy (e.g., "allow `write_file` only under `/workspace`").

These are two layers of defense-in-depth:

- **Server layer:** The server refuses to operate outside its allowed directories, regardless of what ContextForge says.
- **ContextForge layer:** ContextForge can deny specific tool calls or restrict arguments (e.g., deny `delete_file`, restrict `write_file` to certain paths) before the request reaches the server.

They don't conflict — ContextForge is the outer gate, the server is the inner gate. If ContextForge allows a call, the server still validates the path. If the server is misconfigured, ContextForge still blocks disallowed operations.

**Decision:** ContextForge is minimally restrictive on filesystem path policy. The server owns path confinement; ContextForge owns observability and coarse tool-level guardrails. Rationale:

- The server's path confinement is already strong: canonicalization, symlink-escape rejection, `../` traversal blocking, and immutable allowed directories (MCP Roots disabled at startup — the client cannot change allowed directories at runtime).
- Read-only-by-default means the agent cannot write anything unless `--allow-write` is explicitly passed. This handles the biggest risk at the server layer.
- The container provides OS-level isolation (`--cap-drop ALL`, `--read-only` rootfs, minimal UID).
- Duplicating path policy in ContextForge creates configuration drift risk and another thing to maintain.

**What ContextForge still does for filesystem** (without duplicating path policy):

- **Audit logging** — record all filesystem tool calls (who, what, when, result).
- **Rate limiting** — prevent runaway file operations.
- **Optional coarse tool denylist** — e.g., deny `delete_file` or `move_file` as an extra guardrail. This is a simple tool-name list, not per-argument path conditions.

The two layers remain defense-in-depth: ContextForge is the outer gate (audit, rate limit, optional tool deny), the server is the inner gate (path confinement, read-only enforcement, traversal/symlink protection). If ContextForge allows a call, the server still validates the path. If the server is misconfigured, ContextForge still audits and rate-limits.

### 3. How does this coexist with the Obsidian MCP server (which also touches files)?

`cyanheads/obsidian-mcp-server` provides vault operations (note CRUD, search, tags, frontmatter) with folder-scoped RBAC (`OBSIDIAN_READ_PATHS`, `OBSIDIAN_WRITE_PATHS`). It uses the Obsidian Local REST API plugin, not direct filesystem access.

The filesystem MCP server provides general file operations (read, write, edit, search, tree, ZIP) with path confinement.

Potential overlap:

- Both can read/write files in the Obsidian vault directory.
- The Obsidian server has richer semantics (frontmatter, tags, wikilinks, Omnisearch) but only works on the vault.
- The filesystem server is general-purpose but lacks Obsidian-specific semantics.

**Decision:** No restriction. Both servers are exposed as-is; the agent decides which to use for a given task. ContextForge does not enforce routing between them. Each server enforces its own protections independently — the filesystem server confines paths to its allowed directories, and the Obsidian server enforces `OBSIDIAN_READ_PATHS`/`OBSIDIAN_WRITE_PATHS`. If the vault is within the filesystem server's allowed directories, the agent can reach it through either server; if not, only the Obsidian server can touch it. The operator decides at config time whether to include the vault path in the filesystem server's allowed directories.

---

## Next steps

- ~~Decide on container deployment model~~ — **Decided: run inside the Hermes container (option 1).**
- ~~Define the allowed directories and how they're configured~~ — **Deferred to guide writing. Configuration method decided: CLI args at startup, MCP Roots disabled. Directory list is reader-specific.**
- ~~Decide on ContextForge path policy interaction~~ — **Decided: ContextForge minimally restrictive; server owns path confinement, ContextForge owns audit/rate-limit/optional tool denylist.**
- ~~Determine vault exclusion strategy for coexistence with Obsidian MCP server~~ — **Decided: no restriction; agent decides which server to use. Operator decides at config time whether to include vault path in filesystem server's allowed directories.**
