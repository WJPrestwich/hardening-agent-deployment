# Should the hardened Hermes guide use LlamaFirewall?

Yes — as an **additional** content-scanning layer, not as a replacement for the network/runtime isolation the guide already builds.

The current guide already has content inspection on the egress path through **Pipelock**, which performs DLP scanning and response-injection detection on outbound HTTP traffic. What it does not have is prompt-injection detection, adversarial-prompt analysis, or static analysis of generated code before execution. LlamaFirewall can cover those gaps.

---

## What the current guide actually does

The hardened Hermes guide is built around runtime, network, and content controls:

- **Pipelock** (host-side) forces all HTTPS egress through an inspecting proxy with domain allowlists, DLP body scanning, response scanning, and signed evidence receipts.
- **Host firewall (`DOCKER-USER`)** blocks direct internet egress from the container.
- **Hardened Docker container**: non-root, `--cap-drop ALL`, `--read-only` rootfs, cgroup limits.
- **Tirith** scans shell commands before execution, `tirith_fail_open: false`.
- **Read-only `/etc/hermes/config.yaml`** prevents the agent from disabling its own guardrails.
- **Website blocklist / PII redaction / secret redaction** in Hermes config.

See [`hermes-agent/why-this-approach.md`](../../hermes-agent/why-this-approach.md), [`hermes-agent/configure-hermes.md`](../../hermes-agent/configure-hermes.md), and [`hermes-agent/assets/hermes-config.yaml`](../../hermes-agent/assets/hermes-config.yaml).

Pipelock explicitly scans outbound request/response bodies and responses for sensitive patterns and injection payloads. The guide is therefore not missing content inspection entirely; it is missing **prompt-attack and generated-code** inspection.

---

## What LlamaFirewall adds

LlamaFirewall is Meta's open-source guardrail framework. It is modular, so we can use only the pieces we want:

- **PromptGuard 2** — small classifier for prompt injection / jailbreak detection. The jailbreak label can be disabled or ignored.
- **Agent Alignment Checks** — chain-of-thought auditor. Not needed for personal use.
- **CodeShield** — static analysis of generated code (regex + Semgrep, 8 languages, 50+ CWEs). This is the main capability we care about.

For our deployment the useful configuration is essentially **CodeShield only**, with PromptGuard optionally enabled for pure prompt-injection detection if we decide we want it.

---

## Rebutting the earlier objections

### "It runs in-process and can be bypassed"

LlamaFirewall is distributed as a Python library, but nothing forces it to live inside the Hermes container. We can run it as a **container** on the same isolated `agentnet` bridge and expose its scanners over a small HTTP wrapper. The agent container then calls the container for code-scanning decisions; a compromised agent cannot monkey-patch a separate container. This is the same pattern the guide already uses for Pipelock.

There is no official LlamaFirewall Docker image, but building one is straightforward: install the `llamafirewall` package, pre-download the CodeShield rules (and PromptGuard weights if used), and run a tiny FastAPI/Flask wrapper around `lf.scan()`.

### "Downloads conflict with the no-direct-internet rule"

Model weights and rule sets are a **setup-time** concern, not a runtime concern. The guide's "no direct internet" rule means the running container cannot make uninspected outbound connections; it does not mean the host can never download software during install. We can:

- Download PromptGuard weights and CodeShield artifacts on the host during setup, or
- Bake them into the container image at build time.

At runtime LlamaFirewall runs locally. The container needs no external network beyond what the rest of the stack already allows.

### "The license and dependency weight are problems"

For personal use these are not blockers. CodeShield is MIT. PromptGuard weights use Meta's Llama Community License, which is fine for a personal deployment. The `torch`/`transformers` dependencies are heavy, but on a modern workstation with a GPU that is acceptable. If the weight becomes annoying, PromptGuard can simply be left off.

### "It does not handle native Hermes tools"

Correct, but that is a separate topic. The current guide also leaves native tools enabled (it sets `terminal.backend: local` and relies on Tirith). Native-tool containment is the next design task; it is not a reason to reject LlamaFirewall for the content-scanning layer.

---

## Where LlamaFirewall fits relative to Pipelock

Pipelock and LlamaFirewall are complementary content scanners:

| Control | What it scans | What it looks for |
|---------|---------------|-------------------|
| **Pipelock** | All outbound HTTPS traffic | Domain allowlist, SSRF, DLP, signed audit, response injection |
| **LlamaFirewall CodeShield** | Generated code snippets before execution | Dangerous APIs, insecure patterns, CWEs |
| **LlamaFirewall PromptGuard** *(optional)* | User/system prompts | Prompt-injection patterns (jailbreak label disabled) |

Pipelock protects the network path from leaking secrets and from unauthorized destinations; LlamaFirewall protects the agent from executing insecure generated code and from some prompt-based attacks.

---

## Recommended integration

Add LlamaFirewall as a **content-scanning container** alongside Pipelock:

```
HOST (Ubuntu)
┌───────────────────────────────────────────────────────────────────────────┐
│  ContextForge   Pipelock (:8888)   LlamaFirewall container (:<port>)      │
│       │                │                                  │               │
│       │                │                                  │               │
│       │                └────────── agentnet bridge ───────┘               │
│       │                          │                                        │
│       │                ┌─────────┴─────────┐                              │
│       └───────────────►│  Hermes container  │                              │
│                        │ - MCP tools → ContextForge                        │
│                        │ - HTTPS_PROXY → Pipelock                          │
│                        │ - code scanner → LlamaFirewall                    │
│                        └─────────────────────┘                             │
└───────────────────────────────────────────────────────────────────────────┘
```

The container exposes one endpoint for our use case:

- `POST /scan/code` — receives a code snippet and returns `allow`/`block` plus matched rules.

Hermes' `execute_code` path, or an MCP code-execution server, sends generated code to this endpoint before running it. If CodeShield reports a match, execution is blocked and logged. This is deterministic, fast, and auditable.

PromptGuard can be added later as an optional input filter by pointing the container at user prompts as well, with the jailbreak label mapped to `allow`.

---

## What this means for the research plan

- **Keep the current guide's network/runtime layers.** Pipelock, Tirith, and the firewall are still the right foundation. **No credential broker is used**: credentials live in the Hermes/MCP-server environment as tightly scoped static tokens.
- **Pipelock still performs egress DLP scanning and response scanning.** LlamaFirewall adds prompt-attack and generated-code scanning on top.
- **Add LlamaFirewall CodeShield as the generated-code scanner.** This replaces the need to build a custom Semgrep/Bandit pipeline from scratch; CodeShield already is a Semgrep-based scanner with a curated rule set.
- **Skip PromptGuard and AlignmentCheck for now**, or enable PromptGuard only after tuning the labels.
- **Build a container** for LlamaFirewall rather than installing it inside the agent container.

---

## Bottom line

For the content-guardrail layer, **we are better served adding LlamaFirewall (specifically CodeShield) than building our own**, because it adds prompt-attack and generated-code scanning that Pipelock does not provide. It does not replace the current guide; it complements it.

---

## Sources

- `hermes-agent/README.md`
- `hermes-agent/why-this-approach.md`
- `hermes-agent/configure-hermes.md`
- `hermes-agent/assets/hermes-config.yaml`
- `hermes-agent/assets/hermes-run`
- Meta LlamaFirewall paper (arXiv 2505.03574)
- Meta LlamaFirewall docs (`meta-llama.github.io/PurpleLlama/LlamaFirewall`)
- PurpleLlama GitHub (`meta-llama/PurpleLlama`)
