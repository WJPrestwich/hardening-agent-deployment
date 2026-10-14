# Troubleshooting

If a section in the main guide tells you to come here, start with the symptom below. Otherwise work through the general first steps, then pick the area that matches your problem.

## General first steps

1. Check the logs of the failing service: `sudo journalctl -u <service> -n 100 --no-pager`.
2. Confirm the previous milestone still works (for example, do not debug the container until `docker run --rm --gpus all nvidia/cuda:... nvidia-smi` works on the host).
3. Verify file paths and permissions. Most host-side files should be owned by `root` or a dedicated service user, not by your normal login user.
4. Re-read the verification commands in [Verify each layer](./verify-each-layer.md). A failing verification test usually points directly at the broken layer.

## Troubleshooting by area

- [Host setup and Docker daemon](./troubleshooting-host.md) — GPU driver, Docker Engine, NVIDIA Container Toolkit, `daemon.json`
- [Network isolation](./troubleshooting-network.md) — `agentnet` bridge, firewall rules, lockouts
- [ClawShell and Pipelock](./troubleshooting-services.md) — credential broker and egress proxy services
- [Image, container, and vLLM](./troubleshooting-container.md) — build, scan, run, configure, local inference

## General operations

### Services do not start after reboot

- Enable them: `sudo systemctl enable agentnet-firewall pipelock clawshell`.
- Re-apply firewall rules after a Docker daemon upgrade: `sudo /usr/local/sbin/agentnet-firewall.sh apply`.

### I suspect the container is compromised

- Follow the incident response playbook in [Incident response](./incident-response.md) **before** removing the container. Preserve evidence first.

---

← Previous: [Incident response](./incident-response.md) | Next: [Glossary](./glossary.md) →
