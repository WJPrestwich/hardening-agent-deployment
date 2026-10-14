# Operator interface and observability — RESOLVED

Addressing [25-research-summary.md](./25-research-summary.md) §4.1.

---

## Hermes native interfaces (in-process, untrusted)

All of these run inside the Hermes Python process. They are rich but cannot be trusted as security boundaries — a compromised agent can manipulate what they show.

1. **CLI** — interactive terminal with slash commands: `/status` (session info, model, tokens, duration, recent tools, files touched), `/sessions` (session picker), `/model`, `/details` (verbose tool-call details toggle), `/usage` (token/cost/context panel), `/agents` (subagent tree with kill/pause controls).

2. **TUI** (`hermes --tui`) — React/Ink terminal UI with modal overlays, live streaming, subagent observability overlay (`/agents` shows live subagent tree with per-branch cost/token/file rollups, turn-by-turn history).

3. **Web dashboard** (`hermes dashboard`, port 9119) — browser-based admin panel:
   - **Status page** — agent version, gateway state, connected platform statuses, session count, 20 most recent sessions with model/tokens/usage/previews. Auto-refreshes every 5 seconds.
   - **Chat tab** — full TUI embedded in browser via xterm.js (slash commands, tool-call cards, approval prompts all work).
   - **MCP catalog toggles, credential management, webhook config, memory config, gateway controls, System page, Channels page, pluggable auth** (user/pass, self-hosted OIDC, `hermes dashboard register`).

4. **Desktop app** (Electron, macOS/Linux/Windows) — connects to remote gateway over secure WebSocket with OAuth or user/pass. Per-profile remote hosts, cross-profile `@session` links.

5. **Messaging gateway** — 20+ platforms (Telegram, Discord, Slack, WhatsApp, Signal, Matrix, Mattermost, Email, SMS, DingTalk, Feishu, WeCom, iMessage, Home Assistant). Bidirectional — operator sends instructions and receives notifications. Doubles as exfiltration risk (native `messaging`/`send_message`/`discord` toolsets are disabled in hardened config).

6. **Langfuse observability plugin** — built-in, sends turns/LLM calls/tool invocations/latency/token usage/cost to Langfuse tracing dashboard.

7. **`pre_tool_call` hook** — logging/telemetry only, not a trust boundary. Fails open on crash.

8. **MLOps/RL trajectory export** — trajectory data export.

9. **API server** (OpenAI-compatible, port 8642) — can connect to Open WebUI or other frontends.

10. **ACP (Agent Client Protocol)** — editor integrations.

## Out-of-process trusted surfaces

1. **ContextForge Admin UI** — web dashboard for server/tool/config management, request logging, OpenTelemetry. Not an approval interface.
2. **Pipelock audit trail** — signed evidence receipts in `/var/lib/pipelock/evidence/` and `journalctl -u pipelock`.
3. **JSON Lines audit logs** (planned, schema TBD) — tool-call allow/deny decisions, matched rules, Pipelock egress decisions, CodeShield scan results. To a host bind-mount.
4. **Weekly health-check script** — aggregates all control-plane services into a pass/fail report.

## Resolution

**Decision: Yes — the operator can rely on Hermes' native interfaces for security visibility.** The out-of-process trusted surfaces (ContextForge Admin UI, Pipelock audit trail, JSON Lines logs, weekly health-check) remain as defense-in-depth and tamper-evident audit trail, but are not the operator's primary window for day-to-day visibility.

**Sub-question resolutions:**

- **Is JSON Lines to a bind-mount sufficient if the operator is already watching Hermes' own output?** JSON Lines is defense-in-depth / forensic audit trail, not the primary visibility surface. The operator watches Hermes' native interfaces; JSON Lines is there for after-the-fact investigation when Hermes' own output is suspect or unavailable.
- **Does ContextForge's admin UI provide enough visibility on its own?** It's a supplement (server/tool/config management, request logging), not the primary window.
- **How do denied actions surface in real time vs. after the fact?** Real time via Hermes' native interfaces (tool-call cards, TUI `/details`, streaming output show denials inline). After the fact via JSON Lines audit logs and Pipelock receipts.
- **Do we need a dashboard (Grafana/Prometheus), or can we rely on existing interfaces?** Rely on existing interfaces for the first guide version. No additional dashboard stack. ContextForge exposes Prometheus metrics natively if the operator wants one later — optional, not prescribed.

**Accepted residual risk:** A compromised agent can manipulate what Hermes' native interfaces display. The operator accepts this in exchange for a simpler single-host deployment. The tamper-evident out-of-process logs (Pipelock receipts, JSON Lines to a host bind-mount that Hermes cannot write to) are the forensic backstop if Hermes' output is suspected to be tampered.
