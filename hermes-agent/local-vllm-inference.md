# Local vLLM inference

Use this section **instead of** [API-provider inference](./api-provider-inference.md) if you want all LLM inference to stay on-box. Complete [Configure Hermes](./configure-hermes.md) first, then follow either this file or the API-provider file. The security settings, proxy environment variables, and verification steps are identical; only the model block in `/etc/hermes/config.yaml` and the container image change.

By the end of this section you will have:

- A vLLM-extended image built from the scanned Hermes base image and scanned itself.
- A verified model directory mounted read-only into the container.
- vLLM running on loopback inside the container, reachable only by Hermes.
- Hermes repointed at `http://127.0.0.1:8000/v1` so the LLM channel never leaves the sandbox.

This removes the provider egress path entirely, but it consumes GPU memory and compute inside the same sandbox.

## Build the vLLM-extended image

Save [`assets/Dockerfile.hermes-vllm`](./assets/Dockerfile.hermes-vllm) as `Dockerfile.hermes-vllm` in your build directory:

```bash
cp hermes-agent/assets/Dockerfile.hermes-vllm Dockerfile.hermes-vllm
```

Build from the pinned/scanned Hermes tag:

```bash
export HERMES_VERSION=X.Y.Z   # the scanned tag you built earlier
export VLLM_VERSION=A.B.C     # replace with the vLLM release you verified

docker build \
  --build-arg HERMES_VERSION=${HERMES_VERSION} \
  --build-arg VLLM_VERSION=${VLLM_VERSION} \
  -t hermes-guest:vllm-${VLLM_VERSION} \
  -f Dockerfile.hermes-vllm .
```

Scan the vLLM-extended image the same way you scanned the base image:

```bash
trivy image \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  hermes-guest:vllm-${VLLM_VERSION}
```

## Provide the model

The cleanest air-gapped path is to download the model on a trusted host, verify its checksum/signature if available, and mount it into the container read-only. Here we assume the model lives at `/opt/models/Llama-3.1-8B-Instruct` on the host.

Verify the model before mounting it:

```bash
# On the trusted download host, if the publisher provides a checksum file:
cd /opt/models/Llama-3.1-8B-Instruct
sha256sum -c Llama-3.1-8B-Instruct.sha256
```

## Start the vLLM container

Start the container with an extra mount and enough shared memory for vLLM. The command is the same as the hardened `hermes-run` command with three changes:

1. Use the `hermes-guest:vllm-${VLLM_VERSION}` image.
2. Mount the read-only model directory at `/models`.
3. Add `--shm-size` large enough for vLLM's inter-process communication. A safe starting point is at least the model's memory footprint; `8g` works for many 7–8B parameter models. Increase this if you load larger models or see vLLM crash with shared-memory errors.

For the first vLLM smoke test, set `HERMES_RESTART=no` so a bad model path or CUDA mismatch doesn't loop. Use [`assets/hermes-run-vllm`](./assets/hermes-run-vllm):

```bash
export HERMES_VERSION=X.Y.Z   # base Hermes image tag; must match the scanned base
export VLLM_VERSION=A.B.C     # vLLM extension tag you built and scanned
export HERMES_RESTART=no      # change to unless-stopped after the smoke test passes
hermes-agent/assets/hermes-run-vllm
```

`hermes-run-vllm` is the hardened `hermes-run` command with three additions:

1. Uses the `hermes-guest:vllm-${VLLM_VERSION}` image.
2. Mounts the read-only model directory at `/models`.
3. Adds `--shm-size` large enough for vLLM's inter-process communication (`8g` by default; increase for larger models).

You can override the defaults with environment variables:

```bash
MODELS_DIR=/mnt/models SHM_SIZE=16g HERMES_MEMORY=48g hermes-agent/assets/hermes-run-vllm
```

## Start vLLM inside the container

Inside the container, start vLLM on loopback so the host firewall is not involved. The [`assets/start-vllm.sh`](./assets/start-vllm.sh) helper does the following:

1. Runs `vllm serve /models/Llama-3.1-8B-Instruct --host 127.0.0.1 --port 8000` in the background via `nohup`.
2. Logs output to `/tmp/vllm-logs/vllm.log`.
3. Polls `http://127.0.0.1:8000/health` for up to 5 minutes, printing progress.
4. Prints the last 50 log lines if vLLM never becomes healthy.

Save the helper to the host and run it:

```bash
cp hermes-agent/assets/start-vllm.sh . && chmod +x start-vllm.sh && ./start-vllm.sh
```

Expected: `vLLM is healthy` after the model loads.

> For production uptime, do not rely on a one-off `docker exec`. Run vLLM under a process supervisor inside the container (for example, a custom entrypoint that starts vLLM before launching Hermes) so the model server restarts if it crashes.

## Repoint Hermes at the local endpoint

Edit `/etc/hermes/config.yaml` on the host. Keep the security block from [Configure Hermes](./configure-hermes.md); only the `model` block changes:

```yaml
model:
  provider: custom
  base_url: http://127.0.0.1:8000/v1
  default: meta-llama/Llama-3.1-8B-Instruct
  api_key: dummy
```

Because the model server listens on `127.0.0.1`, traffic never leaves the container and never hits the host firewall. ClawShell is no longer needed for model calls, but you can still keep it in front of any cloud tools the agent uses.

> vLLM may need a writable Hugging Face cache directory during model load. If you see permission errors, set `HF_HOME=/tmp/hf` in the container environment (we already provide a writable `/tmp`).

---

← Previous: [Configure Hermes](./configure-hermes.md) | Next: [Verify each layer](./verify-each-layer.md) →
