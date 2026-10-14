# Troubleshooting: network isolation

Problems with the `agentnet` bridge or the host firewall rules.

## `docker network create agentnet` fails

- Check whether the network already exists: `docker network ls`.
- Check for subnet conflicts with existing Docker networks or your LAN.

## The firewall script reports `DOCKER-USER chain does not exist`

- Docker must be running when the script applies rules. Start Docker first: `sudo systemctl start docker`.
- If Docker is running and the chain is still missing, ensure `br_netfilter` is loaded and the sysctl values are set. See the prerequisites in [Lock down the agent network](./agentnet-firewall.md).

## External destinations are still reachable from the container

- Re-apply the firewall: `sudo /usr/local/sbin/agentnet-firewall.sh apply`.
- Verify the service is active: `sudo systemctl is-active agentnet-firewall`.
- Check that Docker did not rewrite its chains: `sudo iptables -L DOCKER-USER -n --line-numbers`.
- If you use UFW or firewalld, see the [host firewall appendix](./host-firewall-appendix.md); these tools can reorder or flush `DOCKER-USER` rules.

## I locked myself out of the host

- If you followed the safety check, you still have a second SSH session open. From that session run `sudo /usr/local/sbin/agentnet-firewall.sh clear`.
- If you did not keep a second session open, reboot from your VPS console or physical access. The `agentnet-firewall` service was not enabled yet, so the rules will not reapply automatically.

---

← Back to [Troubleshooting](./troubleshooting.md)
