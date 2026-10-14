# Troubleshooting: ClawShell and Pipelock

Problems with the host-side credential broker and egress proxy services.

## ClawShell

### `cargo install clawshell` fails

- Install Rust first: see [rustup.rs](https://rustup.rs/) or `sudo apt-get install cargo` on Ubuntu.
- Alternatively build or download a release binary from the ClawShell project repository.

### `sudo systemctl status clawshell` shows it failed to start

- Check the unit log: `sudo journalctl -u clawshell -n 100 --no-pager`.
- Confirm `/etc/clawshell/clawshell.toml` exists and is readable by the `clawshell` user.
- Confirm the `agentnet` bridge exists and `172.30.0.1` is reachable: `ip addr show br-agentnet`.

### The agent cannot reach the LLM endpoint

- Verify ClawShell is listening: `sudo ss -tlnp | grep 18790`.
- Check the virtual key in `/etc/hermes/config.yaml` matches a `[[keys]]` entry in `/etc/clawshell/clawshell.toml`.
- Watch live logs while triggering a request: `sudo clawshell logs --follow`.

## Pipelock

### `pipelock` fails to start

- Check the unit log: `sudo journalctl -u pipelock -n 100 --no-pager`.
- Validate the config: `sudo -u pipelock pipelock check --config /etc/pipelock/config.yaml`.
- Confirm `/var/lib/pipelock` and `/var/log/pipelock` are owned by `pipelock:pipelock`.

### Allowed destinations are blocked

- Edit `/etc/pipelock/config.yaml` and add the domain to `api_allowlist`.
- Reload or restart Pipelock: `sudo systemctl restart pipelock`.

### HTTPS traffic is not being inspected

- Ensure the agent has `HTTPS_PROXY=http://172.30.0.1:8888` and that `NO_PROXY` does not include the destination you want to inspect.
- Confirm Pipelock is configured for `request_body_scanning.enabled: true` and that TLS termination/inspection is enabled for the relevant domains.

---

← Back to [Troubleshooting](./troubleshooting.md)
