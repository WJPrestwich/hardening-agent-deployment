# Key rotation

This page covers rotating the virtual key that the agent holds and the real provider key that ClawShell holds.

## Rotate the virtual key (fast, no provider dashboard needed)

1. In `/etc/clawshell/clawshell.toml`, add or change the virtual key mapping.
2. `sudo systemctl restart clawshell`.
3. Update `api_key` in `/etc/hermes/config.yaml`.
4. `docker restart hermes` so the new config is read into the read-only mount.

## Rotate the real key (when the provider credential may be compromised)

1. Generate a new key at the provider dashboard.
2. Update the `real_key` in `/etc/clawshell/clawshell.toml`.
3. `sudo systemctl restart clawshell`.
4. Optionally revoke the old key at the provider.

## Revocation runbook

If you suspect the virtual key has been misused:

1. Stop the agent container to freeze its state: `docker stop hermes`.
2. Rotate the real provider key at the provider dashboard, or remove/comment its `[[keys]]` entry in `/etc/clawshell/clawshell.toml`.
3. Restart ClawShell: `sudo systemctl restart clawshell`. The old virtual key now maps to nothing.
4. Check for abuse: `sudo clawshell logs --level error` and `curl -s http://127.0.0.1:18790/admin/stats`.
5. Pull Pipelock receipts to reconstruct what actually left the box.
6. If the container may be compromised, `docker rm hermes` and redeploy from the image; state lives in named volumes you can inspect or discard.
7. Generate a fresh virtual key in `clawshell.toml` and update `/etc/hermes/config.yaml` before starting the replacement container.

---

← Previous: [Back up and restore Hermes](./backup-and-restore.md) | Next: [Incident response](./incident-response.md) →
