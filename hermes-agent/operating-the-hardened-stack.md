# Operating the hardened stack

This phase covers keeping the deployed stack alive, up to date, and auditable. By the end of this section you will know how to:

- Run a short weekly health checklist.
- Update the image without losing state.
- Recover cleanly after a host reboot or Docker daemon upgrade.

Related runbooks are split out into their own pages:

- [Back up and restore Hermes](./backup-and-restore.md)
- [Key rotation](./key-rotation.md)
- [Incident response](./incident-response.md)

Treat the running container as cattle: state lives in the `hermes-state` Docker volume and in host config files, so you can replace the container at any time.

## Weekly checks

Run these from the host. They should take under a minute and confirm the control plane is still intact.

The fastest way is to use [`assets/weekly-health-check.sh`](./assets/weekly-health-check.sh):

```bash
sudo install -m 0755 hermes-agent/assets/weekly-health-check.sh /usr/local/bin/hermes-weekly-check
hermes-weekly-check
```

Expected: all checks report `[PASS]`.

You can also run the individual commands manually:

### Services

```bash
sudo systemctl is-active agentnet-firewall pipelock clawshell
```

Expected: all three report `active`.

### Firewall rules

Docker daemon upgrades can rewrite `DOCKER-USER`, so re-verify the rules are present:

```bash
sudo iptables -L DOCKER-USER -n -v | head
sudo ip6tables -L DOCKER-USER -n -v | head 2>/dev/null || true
```

Expected: `DOCKER-USER` contains the `agentnet` drop rules.

### Pipelock audit trail

```bash
sudo journalctl -u pipelock --since today | grep -iE 'block|deny|dlp|receipt'
sudo ls -lt /var/lib/pipelock/evidence/ | head -n 5
```

Expected: recent signed receipts and any blocks/denials are visible.

### ClawShell health

```bash
sudo clawshell logs --level error
curl -s http://127.0.0.1:18790/admin/stats
```

Expected: no unexpected errors; stats endpoint returns counters.

### Container health

```bash
docker ps --filter name=hermes --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
docker exec hermes nvidia-smi >/dev/null && echo "GPU OK"
```

Expected: `hermes` is `Up`, GPU is visible.

## Updating the image

To deploy a new Hermes version or base-image update:

1. Update `Dockerfile.hermes` (new base digest, new installer checksums, etc.).
2. Rebuild and rescan:
   ```bash
   export HERMES_VERSION=X.Y.Z
   docker build -t hermes-guest:${HERMES_VERSION} -f Dockerfile.hermes .
   trivy image --severity HIGH,CRITICAL --ignore-unfixed hermes-guest:${HERMES_VERSION}
   ```
3. Stop and replace the container:
   ```bash
   docker stop hermes
   docker rm hermes
   HERMES_VERSION=X.Y.Z hermes-run
   ```

The agent's writable state survives in the `hermes-state` Docker volume; the read-only config survives in `/etc/hermes/config.yaml` on the host.

## After a host reboot or Docker daemon upgrade

```bash
sudo systemctl start agentnet-firewall pipelock clawshell
# Re-apply our firewall rules; Docker may have rebuilt its chains
sudo /usr/local/sbin/agentnet-firewall.sh apply
HERMES_VERSION=X.Y.Z hermes-run
```

## What never to do

- Do not `docker exec` into the running container to edit files or install packages.
- Do not run `hermes config set` inside the container — the config is mounted read-only for a reason.
- Do not pull `hermes-guest:latest` and run it without scanning the exact tag.
- Do not disable `agentnet-firewall.service` "temporarily" for debugging without re-enabling it.

---

← Previous: [Verify each layer](./verify-each-layer.md) | Next: [Back up and restore Hermes](./backup-and-restore.md) →
