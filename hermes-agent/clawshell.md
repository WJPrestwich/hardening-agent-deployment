# Setup ClawShell

This phase installs ClawShell as a host-side credential broker so that real API keys never touch the Hermes container. By the end of this section you will have:

- The `clawshell` binary installed system-wide.
- An unprivileged service user and `/etc/clawshell` directory with strict permissions.
- A `clawshell.toml` that maps a virtual key to your real provider key.
- A systemd unit running ClawShell on the `agentnet` bridge gateway (`172.30.0.1:18790`).
- Live logs confirming the service is swapping virtual keys for real keys.

## Install the binary

ClawShell is a credential broker that holds real API keys on the host. See the [ClawShell project page](https://github.com/clawshell/clawshell) for the latest install options and release notes.

### Option 1: Rust/cargo (recommended)

If you do not have Rust installed, install it first via [rustup](https://rustup.rs/):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
```

Then build and install ClawShell. Copy the resulting binary to a system-wide path so the systemd unit can find it without depending on a user's `$HOME`:

```bash
cargo install clawshell --locked
sudo cp "$(which clawshell)" /usr/local/bin/clawshell
```

### Option 2: npm

If you prefer not to install Rust, you can install the published npm package globally. This is faster but pulls in a Node.js dependency chain and may lag behind the Rust release:

```bash
sudo npm install -g @clawshell/clawshell
# Only symlink if npm put the binary somewhere other than /usr/local/bin.
if [[ "$(which clawshell)" != /usr/local/bin/clawshell ]]; then
  sudo ln -s "$(which clawshell)" /usr/local/bin/clawshell
fi
```

## Create the service user and directories

We create the user and directories manually instead of running `clawshell onboard` because `onboard` would try to rewrite a host-side Hermes config (via `hermes config set`) that does not exist in this containerized setup.

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin clawshell
sudo mkdir -p /etc/clawshell /var/log/clawshell /var/lib/clawshell
sudo chmod 700 /etc/clawshell /var/log/clawshell /var/lib/clawshell
sudo chown -R clawshell:clawshell /etc/clawshell /var/log/clawshell /var/lib/clawshell
```

## Configure ClawShell

Save [`assets/clawshell.toml`](./assets/clawshell.toml) to `/etc/clawshell/clawshell.toml`:

```bash
sudo install -o root -g clawshell -m 0640 hermes-agent/assets/clawshell.toml /etc/clawshell/clawshell.toml
```

Edit the file and replace the example `real_key` with your actual provider key. The agent will see only the `virtual_key`, which is useless without ClawShell and can be revoked in one step.

## Install the systemd unit

The `ReadWritePaths` addition is important: ClawShell's own generated unit only guarantees `/var/log/clawshell` is writable, so we explicitly add `/var/lib/clawshell` for the stats file.

Save [`assets/clawshell.service`](./assets/clawshell.service) to `/etc/systemd/system/clawshell.service`:

```bash
sudo cp hermes-agent/assets/clawshell.service /etc/systemd/system/clawshell.service
```

## Start and verify

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now clawshell
sudo systemctl status clawshell
sudo ss -tlnp | grep 18790
sudo clawshell logs --follow
```

Expected: log lines showing the virtual key mapped to the real upstream key. The real key must never appear inside the container.

For key rotation and the revocation runbook, see [Key rotation](./key-rotation.md).

---

← Previous: [Create the agent bridge](./network-isolation.md) | Next: [Setup Pipelock](./pipelock.md) →
