# Lock down the agent network

This phase installs the host firewall rules that enforce the agent container's network isolation. By the end of this section you will have:

- `br_netfilter` enabled and persisted.
- An idempotent `agentnet-firewall.sh` script that drops all forwarded egress except to the ClawShell and Pipelock endpoints.
- A systemd service that re-applies those rules on boot and whenever Docker restarts.
- Evidence from a test container that the proxy is reachable but external destinations are not.

If you use UFW or firewalld, see the [host firewall appendix](./host-firewall-appendix.md) after you finish the main path.

## Minimal steps

If you already understand the networking model and just want to get it working:

1. Enable `br_netfilter` and persist the sysctl values.
2. Copy [`agentnet-firewall.sh`](./assets/agentnet-firewall.sh) and [`agentnet-firewall.service`](./assets/agentnet-firewall.service) into place.
3. Run the safety check with a second SSH session open.
4. Enable the `agentnet-firewall` service.
5. Verify with the `curl` test below.

Read on for the detailed, annotated version of each step.

## Prerequisites

Docker normally loads `br_netfilter` and sets `net.bridge.bridge-nf-call-iptables=1`. If your host has these disabled, the `DOCKER-USER` chain will not see bridge traffic, and most of this section becomes a no-op. Ensure it is on and persists:

```bash
sudo modprobe br_netfilter
sudo sysctl -w net.bridge.bridge-nf-call-iptables=1
sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=1
echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee /etc/sysctl.d/99-bridge-nf-call-iptables.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.d/99-bridge-nf-call-iptables.conf
```

Verify before continuing:

```bash
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables
```

## Install the lockdown script

Save [`assets/agentnet-firewall.sh`](./assets/agentnet-firewall.sh) to `/usr/local/sbin/agentnet-firewall.sh`:

```bash
sudo install -m 0755 hermes-agent/assets/agentnet-firewall.sh /usr/local/sbin/agentnet-firewall.sh
```

Blocked packets are written to the kernel log. View them with:

```bash
sudo dmesg | grep -E "AGENT-(FORWARD|INPUT)-DROP"
# or, if journald is capturing kernel messages:
sudo journalctl -k -g "AGENT-(FORWARD|INPUT)-DROP"
```

## Install the systemd service

Save [`assets/agentnet-firewall.service`](./assets/agentnet-firewall.service) to `/etc/systemd/system/agentnet-firewall.service`:

```bash
sudo cp hermes-agent/assets/agentnet-firewall.service /etc/systemd/system/agentnet-firewall.service
```

## Safety check before enabling

Before you make the lockdown persistent, apply it manually and confirm you still have management access:

1. Open a **second** SSH/admin session and keep it open.
2. From the first session, run:
   ```bash
   sudo /usr/local/sbin/agentnet-firewall.sh apply
   ```
3. From the second session, verify management access and that the rules loaded:
   ```bash
   # Can you still reach the host's management interface?
   ssh -o ConnectTimeout=5 <your-management-ip> true && echo "management path OK"
   # Is the SSH daemon still listening and reachable from the host itself?
   sudo systemctl is-active sshd
   sudo ss -tlnp | grep ':22'
   # Did the lockdown rules actually apply?
   sudo iptables -L DOCKER-USER -n --line-numbers | head -20
   sudo iptables -L AGENT-INPUT -n --line-numbers | head -20
   ```
4. Run the verification commands in the next subsection.
5. Only then make it persistent:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now agentnet-firewall
   sudo systemctl is-active agentnet-firewall
   ```

If you lose access, run `sudo /usr/local/sbin/agentnet-firewall.sh clear` from the second session (or reboot from your VPS console; the service has not been enabled yet, so rules will not re-apply).

Because the service is ordered `After=docker.service`, it re-applies the rules whenever Docker restarts, and `ExecStop` gives you a clean way to lift the lockdown.

## Verify

```bash
sudo iptables -L AGENT-INPUT -n --line-numbers
sudo iptables -L DOCKER-USER -n --line-numbers
```

From the agent network, the proxy should be reachable and external destinations should not. This test uses `curl` because `netshoot` ships different versions of `nc` across tags, while `curl` is consistent:

```bash
docker run --rm --network agentnet curlimages/curl:latest sh -c \
  'curl --max-time 5 -s -o /dev/null -w "%{http_code}\n" -x http://172.30.0.1:8888 https://github.com >/dev/null 2>&1 && echo "pipelock OK" || echo "pipelock FAIL"; \
   curl --max-time 5 -s -o /dev/null -w "%{http_code}\n" https://1.1.1.1 >/dev/null 2>&1 && echo "external leaked" || echo "external blocked"'
```

Expected: `pipelock OK` and `external blocked`.

## Rollback

```bash
sudo systemctl stop agentnet-firewall   # clears our rules
```

## Host firewall compatibility

For the cleanest hardening result, keep the host firewall as raw iptables and let `agentnet-firewall.service` own the rules. If you must use UFW or firewalld, see the [host firewall appendix](./host-firewall-appendix.md).

---

← Previous: [Create the agent bridge](./network-isolation.md) | Next: [Setup ClawShell](./clawshell.md) →
