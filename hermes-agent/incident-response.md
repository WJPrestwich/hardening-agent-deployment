# Incident response

This page is the compromise playbook for the hardened Hermes stack.

## Automated freeze

Use [`assets/incident-response-freeze.sh`](./assets/incident-response-freeze.sh) to automate the critical first steps. The script stops the container, preserves evidence, and prompts you to revoke the compromised credential before redeploying:

```bash
HERMES_VERSION=X.Y.Z hermes-agent/assets/incident-response-freeze.sh
```

By default it stores evidence under `/secure/incident-<date>-<timestamp>/`. You can override this with `EVIDENCE_DIR`.

## Manual playbook

If you prefer to run the steps by hand:

1. **Freeze the agent:**
   ```bash
   docker stop hermes
   ```
2. **Preserve evidence before anything else:**
   ```bash
   docker commit hermes hermes-forensics-$(date +%s)
   sudo mkdir -p /secure/incident-$(date +%Y%m%d)
   sudo cp -a /var/lib/pipelock/evidence /secure/incident-$(date +%Y%m%d)/
   sudo cp -a /var/log/pipelock /var/log/clawshell /secure/incident-$(date +%Y%m%d)/
   docker run --rm \
     -v hermes-state:/data:ro \
     -v /secure:/secure \
     alpine tar czf /secure/incident-$(date +%Y%m%d)/hermes-state.tar.gz -C /data .
   ```
3. **Revoke the compromised credential:**
   - Edit `/etc/clawshell/clawshell.toml` and remove/comment the affected `[[keys]]` entry.
   - `sudo systemctl restart clawshell`.
   - The container's virtual key is now useless even if the attacker still has it.
4. **Reconstruct what happened:**
   - Grep Pipelock evidence receipts for the virtual key and the incident time window.
   - Check `sudo clawshell logs --level error` for abuse of the LLM channel.
   - Inspect the frozen state volume for unexpected files or config changes.
5. **Identify which credentials were exposed:**
   - Search Pipelock receipts for egress to provider domains (e.g., `api.openai.com`, `api.anthropic.com`, `openrouter.ai`) during the incident window. Successful requests there mean the virtual key was used.
   - Search ClawShell logs for the virtual key and any upstream requests made during the incident.
   - List the credentials ClawShell was configured to hold (`/etc/clawshell/clawshell.toml`) and any credentials baked into skills or environment variables in the frozen state volume.
6. **Rotate any cloud credentials** that the agent could have used while compromised.
7. **Redeploy from the scanned image:**
   ```bash
   docker rm hermes
   HERMES_VERSION=X.Y.Z hermes-run
   ```

> Do not run `docker rm hermes` until you have committed a forensics image or copied the state volume and logs.

---

← Previous: [Key rotation](./key-rotation.md) | Next: [Troubleshooting](./troubleshooting.md) →
