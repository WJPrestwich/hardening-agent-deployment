# Network isolation concepts

This page explains the networking model used to isolate the Hermes container. Read it before [locking down the agent network](./agentnet-firewall.md) if you want to understand why the rules are placed where they are.

## Why the firewall is necessary

`agentnet` is created with `--internal`, so Docker itself will not route it to the internet. The iptables rules in the lockdown phase are defense-in-depth: they harden the host against a container that somehow escapes the bridge, and they block local-delivery paths that `--internal` alone does not cover.

## Where to filter container traffic

Docker manages its own iptables rules and inserts them ahead of normal `FORWARD` rules, so naive `FORWARD`/`ufw` rules get bypassed. The correct place for container egress filtering is the **`DOCKER-USER`** chain, which Docker evaluates before its own forwarding rules.

Because ClawShell and Pipelock listen on the **host** (bound to `172.30.0.1`), the container reaches them over the bridge as local-delivery traffic (host `INPUT` chain), while the proxies' own outbound uses the host `OUTPUT` chain — neither is subject to `DOCKER-USER`. That lets us drop *all* forwarded external egress from the container without blocking the proxy path.

## What the rules block

The naive version of this drops only traffic leaving the external interface — but that leaves two holes a compromised agent will happily use: the **cloud metadata endpoint** (`169.254.169.254`, a classic route to host credentials) and **anything on your LAN or any other IP the host itself holds** (reached by local delivery, which never traverses the external interface). The lockdown rules allowlist exactly the two proxy endpoints and then deny everything else — private ranges, link-local, and all other host-local destinations included.

## Four subtleties

1. `DOCKER-USER` rules are matched **after** DNAT, so the `-d` matches apply to the real destination of forwarded packets — which is what we want for the metadata/RFC1918 drops.
2. The agent's own bridge subnet (`172.30.0.0/24`) is within `172.16.0.0/12`, so *forwarded* traffic to any other container or private host on that bridge is also dropped; local-delivery traffic to the gateway uses the `INPUT` chain and is allowed only for the two proxy ports and ICMP echo.
3. The `LOG` rules are source-scoped to the agent subnet and rate-limited, so they will not log every packet on the host.
4. If your host is multi-homed, double-check no second interface offers an alternate path.

## Install-time exception

The container needs egress to fetch Hermes/packages during the image build. The `docker build` step uses the host's network, not the locked-down bridge, so builds work normally. Only the *running* container is locked down. If a running container ever needs one-off external access, allowlist the domain in Pipelock rather than poking the firewall.

---

← Previous: [Create the agent bridge](./network-isolation.md) | Next: [Lock down the agent network](./agentnet-firewall.md) →
