# Hardened Docker Hermes Agent

This guide shows you how to run the Hermes Agent inside a hardened Docker container on your own Ubuntu host with a GPU. The result is a personal agent sandbox where:

- Real API keys never enter the container (ClawShell holds them on the host).
- All internet egress from the container is forced through an inspecting proxy (Pipelock) and blocked at the host firewall.
- Commands are scanned before execution (Tirith) and the config that enables those guardrails is frozen.
- The container itself runs as a non-root user with no capabilities, no new privileges, and a read-only root filesystem.

By the end of the guide you will have a running `hermes` container on an isolated `agentnet` bridge, a scanned and SBOM'd image, host-side secrets and proxy services, and a short verification checklist that proves each layer works.

Start with [Why this guide](./why-this-approach.md) to ground the context of this guide, then proceed through each section.

## Before you start

This guide is designed for a **solo operator** who is comfortable with the Linux command line, systemd, and basic networking. You will run commands as `root` or via `sudo`, edit config files by hand, and debug Docker and iptables when things go wrong.

**Estimated time:** 2–4 hours for the full stack on a clean Ubuntu host, plus 30–60 minutes for the verification checklist. Most of that time is waiting for package installs, image builds, and GPU driver downloads.

**Pick your path:**

```
Do you already have Docker + NVIDIA drivers working on Ubuntu?
│
├─ No  → Start at [Prerequisites](./prerequisites.md), then [Host setup](./host-setup.md)
└─ Yes → Skip to [Docker daemon hardening](./docker-daemon-hardening.md)
         │
         ▼
         Do you want local GPU inference (vLLM) or an API provider?
         │
         ├─ API provider → Use [API-provider inference](./api-provider-inference.md)
         └─ Local vLLM   → Use [Local vLLM inference](./local-vllm-inference.md) instead
```

- **API-provider path (default):** Hermes talks to OpenAI/Anthropic/OpenRouter/etc. through [ClawShell](./clawshell.md). Real API keys stay on the host; the container holds only a virtual key. This is the fastest path to a working agent. Follow [API-provider inference](./api-provider-inference.md) after [Configure Hermes](./configure-hermes.md).
- **Local vLLM path:** All LLM inference stays inside the container on `127.0.0.1`. This removes provider egress entirely but requires more GPU memory and a model download. Follow [Local vLLM inference](./local-vllm-inference.md) instead of the API-provider file after [Configure Hermes](./configure-hermes.md).

If a step fails, see the [troubleshooting guide](./troubleshooting.md) and the [glossary](./glossary.md) before continuing.

## What this guide covers

The guide is organized into three parts:

1. **Setup** — build the stack from a clean Ubuntu host to a running, verified Hermes container.
   - Host preparation: NVIDIA driver, Docker Engine, NVIDIA Container Toolkit, hardened daemon defaults.
   - Control plane: isolated `agentnet` bridge, host firewall, [ClawShell](./clawshell.md) (credential broker), and [Pipelock](./pipelock.md) (egress proxy + DLP + audit).
   - Image and runtime: [build](./image-build.md) and [scan](./image-scan.md) the hardened image, then [run](./run-the-container.md) and [configure](./configure-hermes.md) Hermes. Choose [API-provider inference](./api-provider-inference.md) or [local vLLM inference](./local-vllm-inference.md) for the model path.
   - Verification: prove each security layer works with [Verify each layer](./verify-each-layer.md).
2. **Operations** — keep the stack running, updated, and auditable after setup.
3. **Appendix** — reference pages for troubleshooting, concepts, detailed commands, advanced options, and terminology.

## Setup

1. [Why this guide](./why-this-approach.md)
2. [Prerequisites](./prerequisites.md)
3. [Host setup](./host-setup.md)
4. [Docker daemon hardening](./docker-daemon-hardening.md)
5. [Create the agent bridge](./network-isolation.md)
6. [Lock down the agent network](./agentnet-firewall.md)
7. [Setup ClawShell](./clawshell.md)
8. [Setup Pipelock](./pipelock.md)
9. [Build the hardened Hermes image](./image-build.md)
10. [Scan the hardened Hermes image](./image-scan.md)
11. [Run the container](./run-the-container.md)
12. [Configure Hermes](./configure-hermes.md)
13. [API-provider inference](./api-provider-inference.md)
14. [Local vLLM inference](./local-vllm-inference.md)
15. [Verify each layer](./verify-each-layer.md)

## Operations

- [Operating the hardened stack](./operating-the-hardened-stack.md)
- [Back up and restore Hermes](./backup-and-restore.md)
- [Key rotation](./key-rotation.md)
- [Incident response](./incident-response.md)

## Appendix

- [Troubleshooting](./troubleshooting.md)
- [Network isolation concepts](./network-isolation-concepts.md)
- [Vulnerability triage](./vulnerability-triage.md)
- [Verify manual checks](./verify-manual-checks.md)
- [Host firewall compatibility](./host-firewall-appendix.md)
- [Pipelock MCP proxying](./pipelock-mcp.md)
- [Container security flags explained](./container-flags-explained.md)
- [Glossary](./glossary.md)

## Assets

Copy-paste-ready scripts, Dockerfiles, and configuration files live in [`./assets/`](./assets/).
