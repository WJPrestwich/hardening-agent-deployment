# Create the agent bridge

This phase creates the isolated Docker network that the Hermes container will live on. By the end of this section you will have:

- A custom `agentnet` bridge with no external route (`--internal`).
- Evidence from a test container that the bridge gateway is reachable.

The next phase, [Lock down the agent network](./agentnet-firewall.md), adds the host firewall rules that make the isolation enforceable. ClawShell and Pipelock bind to the bridge gateway, so the network must exist before either service starts.

## Create the bridge

```bash
docker network create --driver bridge \
  --subnet 172.30.0.0/24 --gateway 172.30.0.1 \
  --internal \
  --ipv6=false \
  -o com.docker.network.bridge.name=br-agentnet \
  agentnet
```

`--internal` means Docker will not route this network to the internet; the container can still reach the bridge gateway (and thus the host proxies), but all external egress must go through ClawShell/Pipelock. `--ipv6=false` keeps the network IPv4-only, and the custom bridge name `br-agentnet` lets us reference the interface directly in any extra ip6tables rules.

For why this networking model works, see [Network isolation concepts](./network-isolation-concepts.md).

## Verify the bridge exists

```bash
docker network inspect agentnet --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'
ip addr show br-agentnet
```

Expected: `172.30.0.0/24` and the interface is up.

---

← Previous: [Docker daemon hardening](./docker-daemon-hardening.md) | Next: [Lock down the agent network](./agentnet-firewall.md) →
