# Verify each layer

This phase proves the controls we installed actually work. By the end of this section you will have hard evidence for each claim in the architecture:

- The container runs unprivileged, with all capabilities dropped and no privilege escalation path.
- The GPU is visible to Hermes.
- Direct DNS and internet egress from the container are blocked.
- Pipelock allow-lists only approved destinations and blocks everything else.
- Pipelock DLP catches secrets in request bodies and writes a signed receipt.
- ClawShell swaps the virtual key for the real key on the host, never inside the container.
- The Hermes config file is read-only, so the agent cannot disable its own guardrails.
- The root filesystem is read-only, so the agent cannot install or modify system files.
- Cloud metadata and LAN destinations are unreachable.

## Run the bundled verification script

The fastest way is to use [`assets/verify-hermes-stack.sh`](./assets/verify-hermes-stack.sh):

```bash
sudo install -m 0755 hermes-agent/assets/verify-hermes-stack.sh /usr/local/bin/hermes-verify
sudo hermes-verify
```

Expected: all checks report `[PASS]`.

## Run the checks manually

If you prefer to run the commands by hand, see [Verify manual checks](./verify-manual-checks.md).

## If a test fails

- **`nvidia-smi` fails**: confirm the NVIDIA container runtime is installed and that you ran the scanned image tag. Only add `--group-add` if you see a permission/NVML error.
- **Proxy tests fail**: check Pipelock is running (`sudo systemctl status pipelock`) and that `github.com` is in `/etc/pipelock/config.yaml`.
- **DLP test does not block**: confirm the `aws_access_key` rule is present in `/etc/pipelock/config.yaml` and that Pipelock is inspecting HTTPS rather than merely tunnelling CONNECT.
- **Metadata/LAN curl succeeds**: re-apply the host firewall (`sudo /usr/local/sbin/agentnet-firewall.sh apply`) and verify `agentnet-firewall.service` is active.
- **`ReadonlyRootfs` is false, caps are not dropped, or `touch /etc/pwned` succeeds**: the container was not started with the hardened command or `hermes-run`; stop and recreate it.

---

← Previous: [API-provider inference](./api-provider-inference.md) or [Local vLLM inference](./local-vllm-inference.md) | Next: [Operating the hardened stack](./operating-the-hardened-stack.md) →
