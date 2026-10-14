# Guide update plan

Plan for updating `hermes-agent/` to reflect all settled research decisions.

- **Research reference:** [25-research-summary.md](./25-research-summary.md) — single-file summary of all conclusions.
- **Existing guide:** `hermes-agent/` — 32 markdown files + assets.

---

## 1. What changes

The existing guide is built around four pillars: ClawShell (credential broker), Pipelock (egress/DLP), Tirith (command scanning), and hardened Docker. The update replaces the first pillar and adds three new ones:

| Pillar                     | Status       | Action                                                                                     |
|----------------------------|--------------|--------------------------------------------------------------------------------------------|
| **ClawShell**              | Removed      | Delete; replace with static-credential guidance                                            |
| **Pipelock**               | Kept         | Minor updates (new MCP-server egress domains)                                              |
| **Tirith**                 | Reduced role | Keep fail-closed config; `execute_code`/`terminal` disabled so Tirith scans fewer commands |
| **Hardened Docker**        | Kept         | No change to container flags                                                               |
| **ContextForge** (new)     | Added        | New setup file; MCP gateway with RBAC/ABAC                                                 |
| **MCP servers** (new)      | Added        | 4 new per-server deployment files                                                          |
| **CodeShield** (new)       | Added        | New setup file; generated-code scanning container                                          |
| **JSON Lines audit** (new) | Added        | New observability surface (defense-in-depth)                                               |

The update also changes the trust model: Hermes' native tools are now disabled/replaced rather than merely guarded. `execute_code` and `terminal` are off. Capabilities come through ContextForge-fronted MCP servers.

---

## 2. Proposed new setup flow

```
 1. Why this guide                           ← rewritten (Topic 1)
 2. Prerequisites
 3. Host setup
 4. Docker daemon hardening
 5. Create the agent bridge                  ← updated (Topic 12)
 6. Lock down the agent network              ← updated (Topic 12)
 7. Setup Pipelock                           ← updated (Topic 12)
 8. Setup ContextForge                       ← NEW (Topic 3)
 9. Setup CodeShield                         ← NEW (Topic 4)
10. Build the hardened Hermes image
11. Scan the hardened Hermes image
12. Run the container                        ← updated (Topic 12)
13. Configure Hermes                         ← updated (Topic 9)
14. API-provider inference                   ← rewritten (Topic 10)
15. Local vLLM inference                     ← updated (Topic 10)
16. Deploy MCP servers                       ← NEW section
    16a. llm-sandbox (code execution + shell)  ← NEW (Topic 5)
    16b. Web search + crawl                     ← NEW (Topic 6)
    16c. GitHub                                 ← NEW (Topic 7)
    16d. Obsidian                               ← NEW (Topic 8)
17. Credential scoping                       ← NEW (Topic 10)
18. Audit logging                            ← NEW (Topic 11)
19. Verify each layer                        ← updated (Topic 12)
```

Operations section:
- Operating the hardened stack (updated — Topic 12)
- Back up and restore (updated — Topic 12)
- Key rotation (rewritten — Topic 10)
- Incident response (rewritten — Topic 12)

Appendix:
- Troubleshooting (updated — Topic 12)
- Network isolation concepts (updated — Topic 12)
- Vulnerability triage (unchanged)
- Verify manual checks (updated — Topic 12)
- Host firewall compatibility (updated — Topic 12)
- Container security flags explained (minor — Topic 12)
- Glossary (updated — Topic 12)

---

## 3. Topics

Each topic is self-contained: it creates its new files, writes its assets, and modifies any existing files that are specific to that topic. Cross-cutting files (README, verification scripts, glossary, operations runbooks) are deferred to Topic 12 (final wiring) once all topics are settled.

### 3.1 Topic dependency graph

| Topic | Name               | Depends on |
|-------|--------------------|------------|
| 1     | Trust model        | —          |
| 2     | ClawShell removal  | 1          |
| 3     | ContextForge       | 1, 2       |
| 4     | CodeShield         | 1          |
| 5     | llm-sandbox        | 3, 4       |
| 6     | Search + crawl     | 3          |
| 7     | GitHub             | 3          |
| 8     | Obsidian           | 3          |
| 9     | Hermes config      | 3-8        |
| 10    | Credential scoping | 3-9        |
| 11    | Audit logging      | 3, 4       |
| 12    | Final wiring       | 1-11       |

---

### 3.2 Topic 1: Trust model & architecture

#### 3.2.1 Goal

Rewrite `why-this-approach.md` to establish the new architecture. Everything else references it.

#### 3.2.2 Creates

none

#### 3.2.3 Modifies

- `why-this-approach.md` — major rewrite:
  - Remove ClawShell from trust model diagram and the "core working components" table.
  - Add ContextForge, CodeShield, MCP servers to the diagram.
  - Rewrite the "no credential broker" rationale (reference research §3.7).
  - Update the architecture to show: Hermes (disabled native tools) → ContextForge (RBAC/ABAC, audit) → MCP servers; Hermes → Pipelock → internet; Hermes → CodeShield for generated code scanning.
  - Keep the containers-vs-microVMs and HITL discussion (still valid).
  - Update the trust model to note that Hermes' native `execute_code`/`terminal` are disabled and capabilities come through MCP servers.

#### 3.2.4 Dependencies

None. Done first.

---

### 3.3 Topic 2: ClawShell removal

#### 3.3.1 Goal

Delete ClawShell files and remove all ClawShell references from every other file. This is a standalone sweep — later topics handle the full rewrites of files like `api-provider-inference.md` and `key-rotation.md`.

#### 3.3.2 Deletes

- `clawshell.md`
- `assets/clawshell.service`
- `assets/clawshell.toml`
- `pipelock-mcp.md` (superseded by ContextForge)

#### 3.3.3 Modifies (sweep — remove ClawShell references, leave content gaps for later topics to fill)

- `README.md` — remove ClawShell from setup list, "what this guide covers" summary, pick-your-path flow. Leave placeholders for new files (Topic 12 fills them in).
- `api-provider-inference.md` — remove ClawShell content. Full rewrite deferred to Topic 10.
- `local-vllm-inference.md` — remove ClawShell references. Full update deferred to Topic 10.
- `configure-hermes.md` — remove ClawShell `model.base_url` reference. Full rewrite deferred to Topic 9.
- `key-rotation.md` — remove ClawShell content. Full rewrite deferred to Topic 10.
- `incident-response.md` — remove ClawShell steps. Full rewrite deferred to Topic 12.
- `operating-the-hardened-stack.md` — remove ClawShell from weekly checks. Full update deferred to Topic 12.
- `glossary.md` — remove ClawShell and virtual key entries. Full update deferred to Topic 12.
- `troubleshooting-services.md` — remove ClawShell troubleshooting section. Full update deferred to Topic 12.
- `troubleshooting.md` — remove ClawShell from index.
- `troubleshooting-container.md` — remove ClawShell URL reference.
- `network-isolation.md` — remove ClawShell port (18790).
- `network-isolation-concepts.md` — remove ClawShell from diagram/description.
- `agentnet-firewall.md` — remove ClawShell port.
- `container-flags-explained.md` — remove any ClawShell reference.
- `image-build.md` — remove ClawShell mention.
- `run-the-container.md` — remove ClawShell from smoke test expected logs and `NO_PROXY` explanation.
- `backup-and-restore.md` — remove ClawShell config from backup scope.
- `verify-each-layer.md` — remove ClawShell verification step (#8). Full update deferred to Topic 12.
- `verify-manual-checks.md` — remove ClawShell check. Full update deferred to Topic 12.
- `pipelock.md` — remove ClawShell mention.

#### 3.3.4 Modifies (assets — remove ClawShell references)

- `assets/hermes-config.yaml` — remove ClawShell `base_url`. Full rewrite deferred to Topic 9.
- `assets/hermes-run` — remove `NO_PROXY` ClawShell exception. Full rewrite deferred to Topic 12.
- `assets/pipelock.yaml` — remove ClawShell-specific exemptions if any.
- `assets/verify-hermes-stack.sh` — remove ClawShell check (#8). Full update deferred to Topic 12.
- `assets/weekly-health-check.sh` — remove ClawShell from service list. Full update deferred to Topic 12.
- `assets/incident-response-freeze.sh` — remove ClawShell evidence collection and revocation steps. Full update deferred to Topic 12.
- `assets/restore-hermes-state.sh` — remove ClawShell config restore. Full update deferred to Topic 12.
- `assets/agentnet-firewall.sh` — remove ClawShell port. Full update deferred to Topic 12.

#### 3.3.5 Dependencies

Topic 1 (trust model establishes what replaces ClawShell).

#### 3.3.6 Notes

The guide will be temporarily incomplete after this sweep — files like `api-provider-inference.md` will have content gaps. Later topics fill those gaps. This is expected.

---

### 3.4 Topic 3: ContextForge

#### 3.4.1 Goal

Set up ContextForge as the MCP gateway with RBAC/ABAC, audit logging, and rate limiting.

#### 3.4.2 Creates

- `contextforge.md` — setup guide: install, configure, register MCP servers, define RBAC rules (deny-by-default), enable audit logging, single-container SQLite mode. Includes the ContextForge RBAC model and how it fronts MCP servers.

#### 3.4.3 Assets

- `assets/contextforge.yaml` — server registrations, RBAC rules, audit logging config, rate limits.
- `assets/contextforge.service` — systemd unit.

#### 3.4.4 Modifies

- `network-isolation.md` — add ContextForge port to bridge config.
- `agentnet-firewall.md` — add ContextForge port to allowed list.
- `assets/agentnet-firewall.sh` — add ContextForge port. (Note: this asset is also touched by Topic 12; coordinate.)

#### 3.4.5 Dependencies

Topic 1 (architecture), Topic 2 (ClawShell port removed, freeing the firewall slot).

#### 3.4.6 Open questions to resolve while writing

- What port does ContextForge listen on? (Check ContextForge docs.)
- What are the concrete RBAC allow/deny rules for each MCP server? (Research says deny-by-default; specific rules need to be written.)
- MCP server transport: stdio vs HTTP for each server? (Affects ContextForge config.)

---

### 3.5 Topic 4: CodeShield

#### 3.5.1 Goal

Deploy LlamaFirewall CodeShield as a container that scans generated code before execution.

#### 3.5.2 Creates

- `codeshield.md` — setup guide: deploy CodeShield container, expose `POST /scan/code` endpoint, integration with `llm-sandbox` (Topic 5). PromptGuard and Agent Alignment Checks off by default.

#### 3.5.3 Assets

- `assets/codeshield.service` — systemd unit.
- `assets/codeshield-run` — wrapper script for CodeShield container.

#### 3.5.4 Modifies

- `network-isolation.md` — add CodeShield port to bridge config. (Also touched by Topic 3; coordinate.)
- `agentnet-firewall.md` — add CodeShield port to allowed list.
- `assets/agentnet-firewall.sh` — add CodeShield port.

#### 3.5.5 Dependencies

Topic 1 (architecture). Independent of Topic 3 but both touch network-isolation/firewall files.

#### 3.5.6 Open questions to resolve while writing

- What port does the CodeShield wrapper expose?
- CodeShield integration point: does `llm-sandbox` call CodeShield before execution, or does ContextForge call CodeShield before forwarding to `llm-sandbox`? (Affects both this topic and Topic 5.)

---

### 3.6 Topic 5: llm-sandbox MCP server

#### 3.6.1 Goal

Deploy `vndee/llm-sandbox` for code execution + shell, replacing Hermes' disabled `execute_code` and `terminal` tools.

#### 3.6.2 Creates

- `mcp-llm-sandbox.md` — deployment guide: `SANDBOX_NETWORK_MODE=none`, `SANDBOX_READ_ONLY=true`, `SANDBOX_CAP_DROP=ALL`, `SANDBOX_SECURITY_OPT=no-new-privileges`, CPU/memory limits. ContextForge fronts it. CodeShield integration (code scanned before execution).

#### 3.6.3 Assets

- `assets/mcp-sandbox-run` — wrapper script for llm-sandbox container.

#### 3.6.4 Modifies

- `pipelock.md` — note that llm-sandbox needs no egress (network=none) unless the operator enables network mode.
- `assets/pipelock.yaml` — add npm/pypi domains if the operator enables network mode for llm-sandbox (optional, commented out).

#### 3.6.5 Dependencies

Topic 3 (ContextForge fronts it), Topic 4 (CodeShield scans generated code).

#### 3.6.6 Open questions to resolve while writing

- CodeShield integration: does llm-sandbox call CodeShield directly, or does ContextForge orchestrate the scan-then-execute flow? (Resolve with Topic 4.)

---

### 3.7 Topic 6: Web search + crawl MCP servers

#### 3.7.1 Goal

Deploy `tadmstr/searxng-mcp` + `unclecode/crawl4ai` for web search and crawl/fetch.

#### 3.7.2 Creates

- `mcp-search.md` — deployment guide: SearXNG metasearch + Crawl4AI fetch cascade. Both containers on `agentnet`. Egress through Pipelock. Crawl4AI also exposes its own MCP endpoint for direct crawl capabilities.

#### 3.7.3 Modifies

- `pipelock.md` — add SearXNG upstream search engine domains to allowlist (Google, Bing, DuckDuckGo, etc. — or note that SearXNG needs broad egress for metasearch).
- `assets/pipelock.yaml` — add search engine domains, Crawl4AI dependencies.

#### 3.7.4 Dependencies

Topic 3 (ContextForge fronts it).

#### 3.7.5 Open questions to resolve while writing

- What domains does SearXNG need to reach? (It's a metasearch — it queries Google, Bing, DuckDuckGo, etc. This is a broad allowlist. How to handle?)
- Does Crawl4AI need egress beyond what SearXNG fetches? (Yes — it fetches URLs directly. How does this interact with Pipelock's allowlist?)

---

### 3.8 Topic 7: GitHub MCP server

#### 3.8.1 Goal

Deploy `github/github-mcp-server` for GitHub operations with scoped access.

#### 3.8.2 Creates

- `mcp-github.md` — deployment guide: scoped PAT (fine-grained, minimum repo permissions), `--toolsets` flag, `GITHUB_READ_ONLY=1` for read-only mode, `X-MCP-Readonly` and `X-MCP-Lockdown` headers. ContextForge fronts it.

#### 3.8.3 Modifies

- `assets/pipelock.yaml` — add `api.github.com` (likely already present from current guide).

#### 3.8.4 Dependencies

Topic 3 (ContextForge fronts it).

#### 3.8.5 Open questions to resolve while writing

- Which `--toolsets` to enable by default? (Research says scoped; guide should recommend a minimal set.)

---

### 3.9 Topic 8: Obsidian MCP server + skills

#### 3.9.1 Goal

Deploy `cyanheads/obsidian-mcp-server` for structured vault operations and install `kepano/obsidian-skills` for CLI/format tasks.

#### 3.9.2 Creates

- `mcp-obsidian.md` — deployment guide: folder-scoped RBAC (`OBSIDIAN_READ_PATHS`, `OBSIDIAN_WRITE_PATHS`, `OBSIDIAN_READ_ONLY`), Obsidian Local REST API plugin setup, skills installation (`git clone` to skills directory).

#### 3.9.3 Modifies

- None specific to this topic. (Skills installation touches the Hermes skills directory, but that's documented in the new file.)

#### 3.9.4 Dependencies

Topic 3 (ContextForge fronts the MCP server).

#### 3.9.5 Open questions to resolve while writing

- Does the Obsidian MCP server run inside the Hermes container or as a separate container? (Research doesn't specify; the server uses the Obsidian Local REST API plugin, so it needs network access to the Obsidian vault's host.)

---

### 3.10 Topic 9: Hermes config changes

#### 3.10.1 Goal

Update the Hermes config to disable `execute_code`/`terminal`, register MCP server endpoints (via ContextForge), and remove all ClawShell references.

#### 3.10.2 Modifies

- `configure-hermes.md` — rewrite: add `execute_code`/`terminal` disabled config, add MCP server registration (pointing at ContextForge endpoints), update config asset reference, remove ClawShell `model.base_url` reference. Document the disabled-toolsets list.
- `assets/hermes-config.yaml` — full rewrite: disable `execute_code`/`terminal`, add MCP server config, update `api_key` to real scoped key (not virtual), remove `terminal.backend: local`, remove ClawShell `base_url`. Update `model.base_url` to point directly at provider (through Pipelock) or at ContextForge if ContextForge proxies LLM calls.
- `run-the-container.md` — update smoke test expected logs (no ClawShell connection message; should see ContextForge and MCP server startup).

#### 3.10.3 Dependencies

Topics 3-8 (MCP server endpoints must be known to register them in config).

#### 3.10.4 Open questions to resolve while writing

- Does `model.base_url` point directly at the provider (through Pipelock) or at ContextForge? (ContextForge is an MCP gateway, not an LLM proxy — LLM calls likely go direct through Pipelock. Confirm.)
- What is the full `disabled_toolsets` list? (Reference `17-hermes-native-tools-and-mcp-replacements.md`.)

---

### 3.11 Topic 10: Credential scoping

#### 3.11.1 Goal

Document how to scope static credentials for all services (LLM providers, GitHub, MCP servers) without a broker. Rewrite inference and key-rotation files.

#### 3.11.2 Creates

- `credential-scoping.md` — patterns for tightly scoped static credentials: fine-grained GitHub PATs with minimum repo permissions, per-MCP-server API keys (not shared across servers), provider-side rotation procedures, LLM provider API key scoping. References research §3.7 and §7.2.

#### 3.11.3 Modifies

- `api-provider-inference.md` — full rewrite: API key goes directly in config as a scoped static token. `model.base_url` points at the provider directly (through Pipelock). Remove virtual key concept. Update proxy env vars (`NO_PROXY` no longer needs ClawShell). Cross-reference `credential-scoping.md`.
- `local-vllm-inference.md` — remove remaining ClawShell references. vLLM path is mostly unchanged (no broker needed). Update cross-references.
- `key-rotation.md` — full rewrite: no virtual key / real key split. Rotate static credentials at the provider dashboard. Update config and restart. Revocation runbook: rotate at provider, update config, restart container. No broker to restart.

#### 3.11.4 Dependencies

Topics 3-8 (credential scoping depends on knowing which MCP servers need credentials). Topic 9 (config format is settled).

#### 3.11.5 Open questions to resolve while writing

- How do static credentials get into the container? Env vars in `hermes-run`? Bind-mounted files? (Need to pick a method and document it. This also affects Topic 12's `hermes-run` rewrite.)

---

### 3.12 Topic 11: Audit logging

#### 3.12.1 Goal

Define the JSON Lines audit log schema, host bind-mount, and how to read/search logs.

#### 3.12.2 Creates

- `audit-logging.md` — JSON Lines schema, log forwarding to host bind-mount, what to log (ContextForge tool-call decisions, Pipelock egress events, CodeShield scan results), how to read and search logs (`jq` examples, `journalctl`). References research §3.13 and §7.3. Notes that this is defense-in-depth / forensic backstop, not the primary visibility surface (Hermes native interfaces are primary).

#### 3.12.3 Modifies

- None specific to this topic. (The `hermes-run` bind mount for the log directory is added in Topic 12.)

#### 3.12.4 Dependencies

Topics 3-4 (ContextForge and CodeShield produce the log events). Independent otherwise.

#### 3.12.5 Open questions to resolve while writing

- What fields go in each JSON Lines record? (Need to define a minimal schema: timestamp, source, event type, tool name, decision, details.)
- Where on the host does the bind-mount live? (`/var/log/hermes-audit/`? `/var/lib/hermes-audit/`?)

---

### 3.13 Topic 12: Final wiring

#### 3.13.1 Goal

Update all cross-cutting files that touch every topic. This is done last, once all topics are settled and file paths/ports/endpoints are finalized.

#### 3.13.2 Modifies — Verification

- `verify-each-layer.md` — add ContextForge RBAC enforcement check, CodeShield scan check, MCP server reachability checks, audit log check. Update expected results list.
- `assets/verify-hermes-stack.sh` — add ContextForge, CodeShield, MCP server, audit log checks. Remove any remaining ClawShell check.
- `verify-manual-checks.md` — same changes as verify-each-layer.md for manual versions.

#### 3.13.3 Modifies — Operations

- `operating-the-hardened-stack.md` — add ContextForge, CodeShield, and MCP server health checks to weekly checks. Update service list. Update reboot procedure. Update "what never to do" list.
- `assets/weekly-health-check.sh` — add ContextForge, CodeShield, MCP servers to service list. Remove any remaining ClawShell check.
- `incident-response.md` — full rewrite: add ContextForge audit log preservation, CodeShield log preservation, MCP server state preservation. Update credential revocation to direct provider rotation (no broker). Update evidence collection steps.
- `assets/incident-response-freeze.sh` — same: add ContextForge/CodeShield log preservation, update revocation steps.
- `backup-and-restore.md` — update backup scope: add ContextForge config, CodeShield config, audit logs. Remove ClawShell config.
- `assets/restore-hermes-state.sh` — update restore scope: add ContextForge config. Remove ClawShell config.

#### 3.13.4 Modifies — Reference

- `glossary.md` — add ContextForge, CodeShield, MCP, RBAC/ABAC, llm-sandbox, JSON Lines audit, searxng-mcp, crawl4ai, obsidian-mcp-server entries. Update Pipelock, Tirith, DLP, NO_PROXY entries. Remove ClawShell, virtual key entries (already done in Topic 2 sweep, but verify).
- `troubleshooting-services.md` — add ContextForge troubleshooting section, CodeShield troubleshooting section, MCP server troubleshooting section. (ClawShell section removed in Topic 2.)
- `troubleshooting.md` — update service list in "where to look" section. Add new services to index.
- `troubleshooting-container.md` — add ContextForge endpoint reference, MCP server endpoint references.
- `network-isolation-concepts.md` — update trust model description and diagram to reflect new architecture. (ClawShell removed in Topic 2; this adds the new components.)
- `container-flags-explained.md` — minor cleanup if any ClawShell reference remains.
- `host-firewall-appendix.md` — update port list: add ContextForge, CodeShield, MCP server ports. Remove ClawShell port.

#### 3.13.5 Modifies — Navigation

- `README.md` — full update: add all new files to setup/operations/appendix lists. Update "pick your path" flow. Update "what this guide covers" summary. Update architecture sketch. This goes last so all file paths are finalized.

#### 3.13.6 Modifies — Cross-cutting assets

- `assets/hermes-run` — update env vars (add ContextForge endpoint, update `NO_PROXY`), add bind mounts for audit log directory, add any MCP server config bind mounts. Remove ClawShell env vars.
- `assets/pipelock.yaml` — final pass: ensure all MCP server egress domains from Topics 5-7 are present. Remove any remaining ClawShell exemptions.
- `assets/agentnet-firewall.sh` — final pass: ensure all ports from Topics 3-4 are present. Remove ClawShell port.

#### 3.13.7 Dependencies

All prior topics.

---

## 4. Verification

After all topics are complete, verify:

- [ ] No remaining references to ClawShell, virtual keys, or port 18790 in any file or asset.
- [ ] No remaining references to `pipelock-mcp.md`.
- [ ] All new files are linked from `README.md`.
- [ ] All cross-references between files are valid (no broken links).
- [ ] `hermes-config.yaml` has `execute_code` and `terminal` disabled.
- [ ] `hermes-run` has correct env vars and bind mounts.
- [ ] `verify-hermes-stack.sh` tests all new layers.
- [ ] `weekly-health-check.sh` includes all new services.
- [ ] Glossary covers all new terms.
- [ ] Architecture diagram in `why-this-approach.md` matches the new stack.
- [ ] `assets/agentnet-firewall.sh` includes all new ports.
- [ ] `assets/pipelock.yaml` includes all MCP server egress domains.
