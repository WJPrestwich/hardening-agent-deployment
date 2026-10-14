# F. Human-in-the-loop approval workflows

- **Synchronous (blocking)**: pause the agent until a human decides. Best for
  irreversible or real-time high-stakes actions (send email, destructive
  commands, production changes).
- **Asynchronous (queued)**: enqueue the action and continue. Better for
  throughput, but risks stale context; requires TTL, re-validation, and audit.
- **Risk scoring** should drive the gate type: production + destructive +
  outbound comms → sync; medium-risk writes → async with SLA; reads → auto
  with audit.
- **Email-send workflow example**: draft → queue with body hash → reviewer
  sees summary + full body + risk score → approve/reject → verify hash → send
  with signed receipt.
- **Platform UX**: Slack buttons/modals, Telegram InlineKeyboard, Discord
  Message Components. Always log request_id, agent_id, approver, decision,
  timestamp, payload hash, and provenance.

## Sources

- BuildMVPFast HITL patterns
- Auth0 HITL blog
- Temporal HITL cookbook
- Galileo agent oversight
- AI SDK tool approvals
- n8n community HITL thread
