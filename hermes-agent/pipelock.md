# Setup Pipelock

This phase installs Pipelock, the egress proxy and DLP layer. It sits between the Hermes container and the internet, inspects HTTP/HTTPS traffic, and writes signed evidence receipts. By the end of this section you will have:

- A pinned and verified Pipelock binary installed on the host.
- A `pipelock` system user and directories with strict permissions.
- An allowlist/DLP config at `/etc/pipelock/config.yaml`.
- A signing key for tamper-evident receipts.
- rsyslog and logrotate wired up for audit logs.
- A systemd service listening on `172.30.0.1:8888` inside the `agentnet` bridge.
- A verified signed receipt proving the pipeline works.

## Install the binary

Pin a release and install it:

```bash
VERSION=2.7.0
ARCH=amd64
cd /tmp
curl -fsSLO "https://github.com/luckyPipewrench/pipelock/releases/download/v${VERSION}/pipelock_${VERSION}_linux_${ARCH}.tar.gz"
tar -xzf "pipelock_${VERSION}_linux_${ARCH}.tar.gz"
sudo install -o root -g root -m 0755 pipelock /usr/local/bin/pipelock
```

(Or build the community-only binary with `go install github.com/luckyPipewrench/pipelock/cmd/pipelock@latest`.)

## Create the service user and directories

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin pipelock
sudo mkdir -p /etc/pipelock /var/lib/pipelock/evidence /var/log/pipelock
sudo chown -R root:pipelock /etc/pipelock
sudo chmod 750 /etc/pipelock
sudo chown -R pipelock:pipelock /var/lib/pipelock
sudo chmod 700 /var/lib/pipelock
# rsyslog writes /var/log/pipelock/events.log as user syslog (group adm),
# so the log directory must let the adm group search and open existing files.
sudo chown pipelock:adm /var/log/pipelock
sudo chmod 750 /var/log/pipelock
```

## Generate and edit the config

Save the hardened allowlist/DLP config from the assets:

```bash
sudo install -o root -g pipelock -m 0640 hermes-agent/assets/pipelock.yaml /etc/pipelock/config.yaml
```

Review `/etc/pipelock/config.yaml` and make sure the domains your agent needs (for example, `github.com`) are in the allowlist.

## Generate the signing key

```bash
cd /tmp
sudo pipelock keygen hermes-host
sudo mv hermes-host /etc/pipelock/pipelock-signing-key
sudo mv hermes-host.pub /etc/pipelock/pipelock-signing-key.pub
sudo chown root:pipelock /etc/pipelock/pipelock-signing-key*
sudo chmod 640 /etc/pipelock/pipelock-signing-key
sudo chmod 644 /etc/pipelock/pipelock-signing-key.pub
```

## Validate the config

```bash
sudo -u pipelock pipelock check --config /etc/pipelock/config.yaml
```

Expected: a message indicating the config is valid (for example, `config OK` or a zero exit code). If it reports errors, fix them before continuing.

## Wire up logging

Install rsyslog if it is not already present, then add a dedicated config:

```bash
sudo cp hermes-agent/assets/pipelock-rsyslog.conf /etc/rsyslog.d/20-pipelock.conf
```

Rotate the audit log so it does not fill the disk:

```bash
sudo cp hermes-agent/assets/pipelock-logrotate /etc/logrotate.d/pipelock
```

## Install the systemd unit

```bash
sudo cp hermes-agent/assets/pipelock.service /etc/systemd/system/pipelock.service
```

## Start and verify

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now pipelock
sudo systemctl status pipelock
sudo ss -tlnp | grep 8888
sudo -u pipelock pipelock doctor
```

Expected output from `pipelock doctor` resembles:

```
checking proxy listener on 172.30.0.1:8888 ... ok
checking config load ... ok
checking signing key ... ok
checking evidence directory ... ok
all checks passed
```

Verify that receipts are being signed by checking the newest evidence file:

```bash
sudo pipelock verify-receipt \
  "$(ls -t /var/lib/pipelock/evidence/evidence-*.jsonl | head -n1)" \
  --key /etc/pipelock/pipelock-signing-key.pub
```

Expected output from `verify-receipt`:

```
receipt signature valid
chain hash valid
last checkpoint: <timestamp>
```

If the evidence directory is empty, trigger a test request through Pipelock before verifying:

```bash
# From the host; this should create a receipt even for an allowed destination
curl -x http://172.30.0.1:8888 -s -o /dev/null -w "%{http_code}\n" https://github.com
```

For scanning MCP server traffic, see [Pipelock MCP proxying](./pipelock-mcp.md).

---

← Previous: [Setup ClawShell](./clawshell.md) | Next: [Build the hardened Hermes image](./image-build.md) →
