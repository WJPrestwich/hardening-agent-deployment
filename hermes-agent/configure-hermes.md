# Configure Hermes

This phase freezes Hermes' security settings in a root-owned, read-only host file. By the end of this section you will have:

- `/etc/hermes/config.yaml` on the host containing the Tirith fail-closed configuration and a placeholder `model` block.
- Strict root-owned permissions on that file.
- A container that loads the config read-only and cannot rewrite its own guardrails.

Because we mounted `config.yaml` read-only above, **do not** use `hermes config set` at runtime (it would try to write the frozen file). Instead, author the whole config as a root-owned file on the host *before* starting the container, using the provided asset.

## Install the config file

Save [`assets/hermes-config.yaml`](./assets/hermes-config.yaml) to `/etc/hermes/config.yaml`:

```bash
sudo mkdir -p /etc/hermes
sudo install -o root -g root -m 0644 hermes-agent/assets/hermes-config.yaml /etc/hermes/config.yaml
```

## Set strict permissions

The container user `1000` reads the file through the `:ro` bind mount, so the file only needs to be readable by root:

```bash
sudo chown root:root /etc/hermes/config.yaml
sudo chmod 0644 /etc/hermes/config.yaml
```

## Edit the config before starting the container

Open `/etc/hermes/config.yaml` and set the security block:

- `security.tirith_enabled: true` and `security.tirith_fail_open: false`.

The asset already contains a placeholder `model` block. Choose **one** of the following model paths and follow that file next:

- **[API-provider inference](./api-provider-inference.md)** (default) — Hermes talks to OpenAI/Anthropic/OpenRouter/etc. through ClawShell. Real API keys stay on the host.
- **[Local vLLM inference](./local-vllm-inference.md)** — All LLM inference stays inside the container on `127.0.0.1`. Requires more GPU memory and a model download.

Both paths share the same security block and proxy environment variables; only the `model` block changes.

> **Tirith default gotcha:** despite the "fail-closed" branding, `tirith_fail_open` defaults to **true** (commands proceed if Tirith is missing or times out). Setting it `false` is what gives real fail-closed behavior. Unconditional regardless: the unrecoverable-command blocklist (filesystem wipes, fork bombs, block-device writes) and approval-timeout-denies.
>
> **Skills Guard is automatic.** Hermes scans skill content for suspicious environment access and exfiltration patterns before installing or updating a skill; there is no manual toggle for it.
>
> **Config integrity.** Hermes checksums `config.yaml` on load (`.env` is excluded). Mounting it read-only from a root-owned host file both prevents the agent from tampering with `tirith_fail_open`, `model.base_url`, etc., and keeps the checksum stable across container restarts.

---

← Previous: [Run the container](./run-the-container.md) | Next: [API-provider inference](./api-provider-inference.md) →
