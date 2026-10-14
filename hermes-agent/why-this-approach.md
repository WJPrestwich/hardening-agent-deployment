# Why this guide

Hermes Agent is powerful: it can read your files, run commands, call APIs, and keep working while you step away. That power is also what makes it dangerous. An agent that can act on your behalf can, in principle, be tricked into acting against you — through prompt injection, malicious skills, or just an over-enthusiastic auto-approve setting.

This guide is an attempt to run Hermes on a personal Ubuntu box with a GPU without simply trusting the tool to behave. The idea is not to eliminate every risk — that is impossible — but to make the most likely failures harmless: keep real keys out of the agent, force all its network traffic through an inspecting proxy, scan the commands it wants to run, and lock the whole thing inside a hardened container that has no direct route to the internet.

The sections that follow explain how that setup works and why each layer matters.

## Who this is for

This guide is for a solo operator who wants to run Hermes Agent on their own box with GPU access making use of APIs or local models, without YOLO'ing past security.

I wrote it for my own personal use, not as a paid product or with enterprise-grade security in mind. I wanted a personal agent, but I didn't want to wake up one day to a compromised desktop, stolen credentials, huge bills for tokens that I didn't use, or worse. The Hermes content I could find was mostly creators hyping the tool while glossing over security — talking about guardrails actually hurts engagement, so they don't, not really. This guide captures the steps I actually took to lock things down, shared in the hope that it helps someone else do the same. If you spot something wrong, please open an issue/conversation/PR and correct me.

## Why not just embrace human-in-the-loop

Before picking a runtime, it is worth stating why isolation matters for an autonomous agent at all, and why this architecture rather than simple human approval.

An autonomous agent is a uniquely risky program: it reads untrusted input (prompts, web pages, GitHub issues, skill descriptions), holds credentials, and executes commands on your behalf. Those three things together — untrusted content, secrets, and execution power — are the lethal trifecta of agent security. Take any one away and prompt injection is mostly annoying; with all three present, it becomes remote-code-execution and exfiltration.

Human-in-the-loop approval sounds like the obvious answer, but it has structural problems. The approval dialog is rendered from the same context the attacker can poison, so a prompt-injected agent can forge or misrepresent what you are approving (the Lies-in-the-Loop attack class). Even when the dialog is honest, approval fatigue sets in quickly: gate everything and people reflexively click yes, or they widen auto-approve allowlists until the gate is cosmetic. Requiring a human per action also undermines the point of an autonomous agent.

The better approach is to architect the system so that a compromised agent cannot do much damage even if the human is fooled. Real credentials live outside the agent's reach (ClawShell); the agent has no direct route to the internet and all egress is inspected (firewall + Pipelock); commands are scanned before execution (Tirith); and the whole thing runs inside a hardened container. That shifts the goal from "ask the human to catch every bad action" to "make the bad actions unreachable in the first place."

## Why containers over microVMs

A remaining question is how strong the container boundary needs to be. There are three sensible options, from strongest isolation to the one this guide walks through:

- **Full microVMs** (Kata Containers, Firecracker, and similar) run each workload in its own guest kernel. This is the strongest runtime boundary, but the protection it buys is narrower than it looks: it only helps if an attacker escapes the container through a kernel or hypervisor bug. The attacks you are actually worried about happen *inside* the sandbox and are not stopped by a VM boundary. Worse, GPU passthrough to a microVM is a project: VFIO binding, IOMMU/VT-d, a custom NVIDIA guest kernel and rootfs, cold-plug/CDI configuration, and the GPU becomes exclusive to that one VM — your host loses it. For a personal workstation that is a lot of friction for the protection you arguably need the least.

- **gVisor** (`runsc`) is the practical middle ground. It intercepts syscalls in userspace, so a container escape has to defeat that intercept layer before reaching the host kernel — much stronger than runc, far lighter than a VM, and GPU support via `nvproxy` is dramatically easier than VFIO passthrough. It is the right step up if you start running untrusted third-party code or marketplace skills.

- **Hardened Docker** (this guide) shares the host kernel, which is a real isolation downgrade from a microVM. A container escape therefore lands on the host, whereas a Kata VM would contain it. For a personal box running your own agent that is usually an acceptable risk: the actual threat is agent misbehavior, not kernel exploits, and the other layers in this stack — ClawShell, Pipelock, Tirith, and a strict `DOCKER-USER` firewall — stop the likely damage (key theft, exfiltration, destructive commands) regardless of runtime. GPU access is also just one flag. If you later run untrusted third-party agent code or marketplace skills, reconsider: that is when an escape becomes plausible, and **gVisor** (`runsc`) is the natural next step — stronger isolation than runc via a userspace-kernel syscall intercept, far lighter than Kata, and with easy GPU support (`nvproxy`).

## The trust model

The whole design rests on a central rule: **the agent container has no direct route to the internet.** Its only two reachable destinations are services running on the host, outside the container:

```
                                 HOST (Ubuntu)
   ┌───────────────────────────────────────────────────────────────────────┐
   │                                                                       │
   │   ┌─────────────────────┐           ┌─────────────────────────────┐   │
   │   │ ClawShell (systemd) │           │ Pipelock (systemd)          │   │
   │   │ /etc/clawshell      │           │ /etc/pipelock               │   │
   │   │ ┄ REAL provider keys│           │ ┄ domain allowlist          │   │
   │   │ ┄ virtual→real map  │           │ ┄ DLP / request body scan   │   │
   │   │ ┄ request/response  │           │ ┄ signed evidence receipts  │   │
   │   │   content scanning  │           │                             │   │
   │   └──────────┬──────────┘           └──────────────┬──────────────┘   │
   │              │ :18790                              │ :8888            │
   │              │                                     │                  │
   │              │  both services bind to the bridge   │                  │
   │              │  gateway 172.30.0.1 on the host     │                  │
   │              ▼                                     ▼                  │
   │   ══════════╪════════════════ DOCKER-USER chain ═════════════════════  │
   │   │          │                                                     │  │
   │   │  ┌───────┴─────────────────────────────────────────────────┐   │  │
   │   │  │                    Docker container                     │   │  │
   │   │  │  ┄ runs as non-root user (uid 1000)                     │   │  │
   │   │  │  ┄ --cap-drop ALL, --security-opt no-new-privileges     │   │  │
   │   │  │  ┄ --read-only root filesystem                          │   │  │
   │   │  │                                                         │   │  │
   │   │  │  ┌─────────────────────────────────────────────────┐    │   │  │
   │   │  │  │              Hermes Agent                       │    │   │  │
   │   │  │  │  ┄ holds only a VIRTUAL key                     │    │   │  │
   │   │  │  │  ┄ HTTPS_PROXY  → Pipelock (:8888)              │────┘   │  │
   │   │  │  │  ┄ model.base_url → ClawShell (:18790)          │────────┘  │
   │   │  │  │  ┄ Tirith enabled, fail_open = false            │           │
   │   │  │  └─────────────────────────────────────────────────┘           │
   │   │  └──────────────────────────────────────────────────────────────┘  │
   │   │                                                                    │
   │   │  NO direct route to the internet (blocked by DOCKER-USER + host    │
   │   │  firewall). The only exits are the two labeled arrows above.       │
   │   │                                                                    │
   │   └────────────────────────────────────────────────────────────────────┘
   │
   │   Legend:
   │   ───►  allowed traffic path
   │   ═══   host firewall boundary (DOCKER-USER iptables chain)
   │   ┄┄┄   internal detail / stored secret
   │
   └───────────────────────────────────────────────────────────────────────┘
```

The core working components:

| Layer                    | Job                                                                             |
| ------------------------ | ------------------------------------------------------------------------------- |
| **Hardened Docker**      | Process/namespace isolation; blast-radius containment; resource limits          |
| **ClawShell**            | Holds real keys; agent sees only virtual keys; one-flip revocation              |
| **Pipelock**             | Forces + inspects all other egress (DLP, SSRF, injection); tamper-evident audit |
| **Tirith**               | Pre-execution command scanning, fail-closed                                     |
| **DOCKER-USER firewall** | Makes "no direct internet" real; this is what makes Pipelock unbypassable       |

---

Next: [Prerequisites](./prerequisites.md) →
