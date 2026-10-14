# Back up and restore Hermes

This page covers backing up the agent state and host configs, and restoring them after a failure or onto a new host.

Run these backups before major updates or after important sessions.

## Back up state

### Hermes state volume

```bash
docker run --rm \
  -v hermes-state:/data:ro \
  -v $(pwd):/backup \
  alpine tar czf /backup/hermes-state-$(date +%Y%m%d).tar.gz -C /data .
```

### Host configs

```bash
sudo cp /etc/hermes/config.yaml /backup/config.yaml-$(date +%Y%m%d)
sudo cp /etc/clawshell/clawshell.toml /backup/clawshell.toml-$(date +%Y%m%d)
```

## Restore from backup

To restore the agent state after a failure or onto a new host, use [`assets/restore-hermes-state.sh`](./assets/restore-hermes-state.sh). Pass the date suffix from your backup filenames:

```bash
BACKUP_DIR=/backup HERMES_VERSION=X.Y.Z hermes-agent/assets/restore-hermes-state.sh YYYYMMDD
```

The script validates that the backup files exist, stops and removes the existing container, restores the host configs, restores the `hermes-state` volume, restarts the control-plane services, and starts a fresh container from the scanned image.

---

← Previous: [Operating the hardened stack](./operating-the-hardened-stack.md) | Next: [Key rotation](./key-rotation.md) →
