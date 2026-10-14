# API-provider inference

Use this section to configure Hermes with an API provider (OpenAI, Anthropic, OpenRouter, etc.) brokered through [ClawShell](./clawshell.md). Real API keys stay on the host; the container holds only a virtual key.

This is the default model path. If you want all LLM inference to stay on-box instead, follow [Local vLLM inference](./local-vllm-inference.md) after completing [Configure Hermes](./configure-hermes.md).

By the end of this section you will have:

- `/etc/hermes/config.yaml` pointing `model.base_url` at ClawShell.
- A virtual API key in the config that maps to your real provider key in `/etc/clawshell/clawshell.toml`.
- The proxy environment variables already set by `hermes-run` so HTTPS egress goes through Pipelock while LLM calls bypass it.

## Configure the model block

Before editing, complete [Configure Hermes](./configure-hermes.md) so the security block (`tirith_enabled`, `tirith_fail_open`) is already in place.

Open `/etc/hermes/config.yaml` and set the `model` block:

- `model.provider`: `custom`.
- `model.base_url`: `http://172.30.0.1:18790/v1`. ClawShell exposes an OpenAI-compatible endpoint at `/v1`, so the path is required.
- `model.api_key`: the same virtual key that is mapped in `/etc/clawshell/clawshell.toml`.
- `model.default`: the provider model slug you want to use (for example, `openrouter/nous-hermes-2-mixtral` or `claude-sonnet-4`).

Example:

```yaml
model:
  provider: custom
  base_url: http://172.30.0.1:18790/v1
  default: openrouter/nous-hermes-2-mixtral
  api_key: vk-hermes-001
```

> The virtual key is fine to bake into this host file — it's useless without ClawShell and is revocable in one step. The **real** key never appears here or anywhere in the container.

## Proxy environment variables

Proxy settings are **not** set in `config.yaml`; Hermes reads `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` from the environment. The `hermes-run` wrapper already sets these:

```bash
HTTPS_PROXY=http://172.30.0.1:8888
HTTP_PROXY=http://172.30.0.1:8888
NO_PROXY=172.30.0.1
```

`NO_PROXY=172.30.0.1` ensures LLM calls go straight to ClawShell instead of being double-proxied through Pipelock.

## Restart and verify

If the container is already running with the API-provider config, restart it to pick up the read-only config change:

```bash
docker restart hermes
```

Then verify the LLM path through ClawShell:

```bash
docker exec hermes bash -c \
  'curl -m 5 -H "Authorization: Bearer vk-hermes-001" http://172.30.0.1:18790/v1/models'
```

Expected: a JSON list of models from the upstream provider (or a successful authentication response), with the real key visible only in ClawShell logs on the host.

---

← Previous: [Configure Hermes](./configure-hermes.md) | Next: [Verify each layer](./verify-each-layer.md) →
