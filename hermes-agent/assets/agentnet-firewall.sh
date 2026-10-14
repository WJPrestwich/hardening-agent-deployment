#!/bin/bash
set -euo pipefail

AGENT_SUBNET=172.30.0.0/24
AGENT_IF=br-agentnet
GW=172.30.0.1
CLAWSHELL_PORT=18790
PIPELOCK_PORT=8888

log_drop() {
  local chain="$1" prefix="$2"
  # Rate-limit logging so a noisy agent can't fill the journal.
  # 20/min gives enough signal for troubleshooting without drowning the journal.
  iptables -A "$chain" -s $AGENT_SUBNET -m limit --limit 20/min --limit-burst 30 \
           -j LOG --log-prefix "$prefix" --log-level 4
}

clear_rules() {
  # Remove our custom jump chain from INPUT
  iptables -D INPUT -j AGENT-INPUT 2>/dev/null || true
  iptables -F AGENT-INPUT 2>/dev/null || true
  iptables -X AGENT-INPUT 2>/dev/null || true

  # Flush only DOCKER-USER (Docker owns DOCKER, not DOCKER-USER)
  iptables -F DOCKER-USER 2>/dev/null || true

  # Clean up IPv6 safety-net rules
  if command -v ip6tables >/dev/null 2>&1; then
    ip6tables -D FORWARD -i $AGENT_IF -j DROP 2>/dev/null || true
    if ip6tables -L DOCKER-USER -n >/dev/null 2>&1; then
      ip6tables -F DOCKER-USER 2>/dev/null || true
    fi
  fi
}

apply_rules() {
  clear_rules

  # --- Forwarded egress: DOCKER-USER ---
  if ! iptables -L DOCKER-USER -n >/dev/null 2>&1; then
    echo "WARNING: DOCKER-USER chain does not exist (is Docker running?). Skipping forwarded-egress rules." >&2
  else
    iptables -I DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    # Explicitly kill cloud metadata SSRF and lateral movement to private networks first...
    iptables -A DOCKER-USER -s $AGENT_SUBNET -d 169.254.0.0/16 -j DROP   # incl. 169.254.169.254
    iptables -A DOCKER-USER -s $AGENT_SUBNET -d 10.0.0.0/8     -j DROP
    iptables -A DOCKER-USER -s $AGENT_SUBNET -d 172.16.0.0/12  -j DROP
    iptables -A DOCKER-USER -s $AGENT_SUBNET -d 192.168.0.0/16 -j DROP
    # Log then drop all remaining forwarded egress from the agent subnet.
    log_drop DOCKER-USER "AGENT-FORWARD-DROP: "
    iptables -A DOCKER-USER -s $AGENT_SUBNET -j DROP
    iptables -A DOCKER-USER -j RETURN
  fi

  # --- Host-local delivery: INPUT ---
  iptables -N AGENT-INPUT 2>/dev/null || true
  iptables -F AGENT-INPUT
  iptables -A AGENT-INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A AGENT-INPUT -s $AGENT_SUBNET -d $GW -p tcp --dport $CLAWSHELL_PORT -j ACCEPT
  iptables -A AGENT-INPUT -s $AGENT_SUBNET -d $GW -p tcp --dport $PIPELOCK_PORT -j ACCEPT
  # Allow ICMP echo to the gateway for basic diagnostics.
  iptables -A AGENT-INPUT -s $AGENT_SUBNET -d $GW -p icmp --icmp-type echo-request -j ACCEPT
  # Direct DNS to the host is not needed — the proxies resolve names themselves.
  iptables -A AGENT-INPUT -s $AGENT_SUBNET -p udp --dport 53 -j DROP
  iptables -A AGENT-INPUT -s $AGENT_SUBNET -p tcp --dport 53 -j DROP
  log_drop AGENT-INPUT "AGENT-INPUT-DROP: "
  iptables -A AGENT-INPUT -s $AGENT_SUBNET -j DROP

  # Jump to our chain early in INPUT
  iptables -I INPUT 1 -j AGENT-INPUT

  # --- IPv6 safety net ---
  # agentnet is IPv4-only, but link-local IPv6 addresses can still appear on the
  # interface. Drop anything forwarded from the agent bridge just in case.
  if command -v ip6tables >/dev/null 2>&1; then
    if ip6tables -L DOCKER-USER -n >/dev/null 2>&1; then
      ip6tables -I DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      ip6tables -A DOCKER-USER -i $AGENT_IF -j DROP
      ip6tables -A DOCKER-USER -j RETURN
    else
      ip6tables -I FORWARD 1 -i $AGENT_IF -j DROP
    fi
  fi
}

case "${1:-apply}" in
  clear) clear_rules ;;
  apply|*) apply_rules ;;
esac
