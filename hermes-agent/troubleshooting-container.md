# Troubleshooting: image, container, and vLLM

Problems with building, scanning, running, and configuring the Hermes container, plus the optional local vLLM path.

## Image build, scan, and triage

### `docker build` fails because the base image digest is invalid

- The Dockerfile asset contains `sha256:<paste-base-image-digest>`. Replace it with a real digest:
  ```bash
  docker buildx imagetools inspect \
    nvidia/cuda:12.6.3-runtime-ubuntu24.04 \
    --format '{{json .Manifest.Digest}}'
  ```

### The Hermes installer fails or cannot be downloaded

- Replace `HERMES_VERSION` with a real release version.
- Check the Hermes release page for the current installer URL and published checksum.
- Verify the SHA-256 checksum before running the installer.

### Trivy reports HIGH/CRITICAL vulnerabilities

- See the triage steps in [Vulnerability triage](./vulnerability-triage.md).
- Focus on vulnerabilities with a fixed version available. If no fix exists, document the exception.

## Run the container

### `hermes-run` says the container already exists

- Remove the old container: `docker stop hermes && docker rm hermes`.
- If you want to keep its state, do not remove the `hermes-state` volume; only the container definition is replaced.

### The container exits immediately

- Check the logs: `docker logs hermes --tail 100`.
- For the first start, use `HERMES_RESTART=no hermes-run` so a bad config does not loop.
- Common causes: missing `/etc/hermes/config.yaml`, wrong image tag, or the `agentnet` network not created.

### `nvidia-smi` fails inside the container

- See the GPU permission troubleshooting note in [Run the container](./run-the-container.md).
- Try adding `--group-add video` and/or `--group-add render` to the run command.

## Configure Hermes

### `hermes config set` fails with a read-only filesystem error

- This is expected. The config is mounted read-only on purpose. Edit `/etc/hermes/config.yaml` on the host instead, then restart the container.

### The agent does not use the virtual key

- Check that `model.api_key` in `/etc/hermes/config.yaml` matches a `virtual_key` in `/etc/clawshell/clawshell.toml`.
- Confirm `model.base_url` points to `http://172.30.0.1:18790/v1`.

## Verification

### A single verification check fails

- See the "If a test fails" section in [Verify each layer](./verify-each-layer.md) for check-specific guidance.

### Read-only rootfs or capability checks fail

- The container was not started with the hardened flags. Stop and recreate it with `hermes-run` or the full hardened `docker run` command.

## Local vLLM inference

### vLLM fails to load the model

- Ensure `--shm-size` is large enough for the model.
- Ensure `HF_HOME=/tmp/hf` is set if Hugging Face needs a writable cache.
- Check GPU memory: the model weights must fit in VRAM.

### The model server is running but Hermes cannot reach it

- Confirm vLLM is listening on `127.0.0.1:8000` inside the container.
- Confirm `/etc/hermes/config.yaml` points `model.base_url` to `http://127.0.0.1:8000/v1`.

---

← Back to [Troubleshooting](./troubleshooting.md)
