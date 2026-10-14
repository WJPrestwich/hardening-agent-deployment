# Host firewall compatibility (UFW / firewalld)

This appendix is for readers who cannot disable UFW or firewalld on the agent host. The main guide recommends raw iptables managed by `agentnet-firewall.service`; this page explains the pitfalls and workarounds if you must keep a higher-level firewall tool.

Docker owns the same iptables tables that UFW and firewalld manage. Published ports are DNATed before ordinary `INPUT` filtering, and Docker inserts its forwarding rules ahead of UFW/firewalld rules, so a host-facing "deny incoming" policy does **not** protect container-exposed services. Reloads can also flush or reorder custom rules.

**Recommended path:** keep the host firewall as raw iptables and let `agentnet-firewall.service` own the rules. Disable UFW/firewalld on a dedicated agent host:

```bash
# UFW
sudo systemctl stop ufw
sudo systemctl disable ufw

# firewalld
sudo systemctl stop firewalld
sudo systemctl disable firewalld
```

Only continue below if disabling those tools is not an option.

## If you must keep UFW

Do not try to express container egress policy with `ufw allow/deny` — UFW rules live in the filter table but do not reliably intercept forwarded container traffic. The right place is still `DOCKER-USER`. You have two practical options:

1. **Use the community `ufw-docker` helper.** It writes `DOCKER-USER` rules for you. After installing it, re-run our lockdown script so its rules are still present:
   ```bash
   sudo /usr/local/sbin/agentnet-firewall.sh apply
   ```
2. **Persist a minimal `DOCKER-USER` reference in `/etc/ufw/after.rules`** so UFW does not delete the chain on reload. The file already contains a single `*filter` block that ends with `COMMIT`; add these three lines just before that final `COMMIT`:
   ```iptables
   :DOCKER-USER - [0:0]
   -A DOCKER-USER -j RETURN
   ```
   Then, every time you run `sudo ufw reload`, also reload our rules:
   ```bash
   sudo ufw reload
   sudo systemctl reload agentnet-firewall
   ```

> **Caveat:** UFW reloads can still reorder or flush non-persistent rules. Verify after any UFW change with `sudo iptables -L DOCKER-USER -n --line-numbers`. If your host also uses IPv6, mirror the persistence in `/etc/ufw/after6.rules` and remember that Docker's `DOCKER-USER` support for IPv6 is limited.

## If you must keep firewalld

When Docker's `iptables` option is enabled, firewalld creates a permissive `docker` zone and a `docker-forwarding` policy. For our egress rules, inject them directly into `DOCKER-USER` (firewalld 2.4.0+ also supports `StrictForwardPorts=yes`, which blocks Docker-published ports unless you explicitly forward them):

```bash
# Run once at runtime and once with --permanent so it survives reloads/reboots.
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 0 \
  -s 172.30.0.0/24 -d 169.254.0.0/16 -j DROP
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 0 \
  -s 172.30.0.0/24 -d 10.0.0.0/8 -j DROP
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 0 \
  -s 172.30.0.0/24 -d 172.16.0.0/12 -j DROP
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 0 \
  -s 172.30.0.0/24 -d 192.168.0.0/16 -j DROP
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 0 \
  -s 172.30.0.0/24 -j DROP
sudo firewall-cmd --reload
```

The host-local `INPUT` rules for the proxies must still be added with raw `iptables` (or a firewalld rich rule on the host's management zone) because `DOCKER-USER` does not cover local delivery.

> **Do not** set `"iptables": false` in `/etc/docker/daemon.json` unless you are prepared to recreate Docker's NAT and forwarding rules yourself. Docker warns that this is difficult to do correctly and may leave networking broken.

---

← Back to [Lock down the agent network](./agentnet-firewall.md)
