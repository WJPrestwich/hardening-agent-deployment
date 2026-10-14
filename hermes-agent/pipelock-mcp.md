# Pipelock MCP proxying

If you run MCP servers alongside Pipelock (on the host or in a sidecar), wrap them so their tool calls and responses are scanned too:

```bash
pipelock mcp proxy --config /etc/pipelock/config.yaml -- \
  npx -y @modelcontextprotocol/server-filesystem /allowed/path
```

> Pipelock's own docs are blunt that capability separation is *deployed, not assumed* — the binary inspects, but network isolation is your job (the network lockdown section). Out-of-band channels (raw sockets, direct DNS from tool code) bypass an HTTP proxy entirely, which is why the firewall must be airtight.

---

← Back to [Setup Pipelock](./pipelock.md)
