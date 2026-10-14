# Glossary

Terms and components used throughout the Hermes hardening guide.

## Agent

In this guide, "the agent" means the Hermes Agent running inside the hardened container. It can read files, run commands, call APIs, and install skills.

## Allowlist

A list of destinations or actions that are explicitly permitted. Pipelock uses a domain allowlist: if a domain is not on the list, outbound HTTPS traffic to it is blocked.

## Blast radius

The amount of damage a compromised component can cause. Hardening measures like read-only rootfs, capability dropping, and network isolation exist to reduce blast radius.

## Capabilities

Fine-grained Linux privileges (for example, `CAP_NET_ADMIN`, `CAP_SYS_ADMIN`). The Hermes container runs with `--cap-drop ALL`, meaning it has no special privileges.

## CDI (Container Device Interface)

A standard way for container runtimes to expose host devices like GPUs to containers. The NVIDIA Container Toolkit uses CDI to make GPUs available inside Docker.

## ClawShell

The host-side credential broker. It holds the real API provider keys and swaps a virtual key (known to the agent) for the real key on the fly. This keeps real keys out of the container.

## DLP (Data Loss Prevention)

Scanning outbound traffic for sensitive patterns such as API keys, private keys, or PII. Both ClawShell and Pipelock perform DLP-style scanning.

## DOCKER-USER

A custom iptables chain that Docker evaluates before its own forwarding rules. It is the correct place to add egress filtering for containers because Docker-managed rules cannot bypass it.

## Egress

Outbound network traffic from the container to the rest of the network. The guide forces all egress through Pipelock or ClawShell and blocks direct egress at the firewall.

## Fail-closed / fail-open

- **Fail-closed:** if a security check cannot run, the action is denied. In this guide, `tirith_fail_open: false` means Hermes blocks commands it cannot scan.
- **Fail-open:** if a security check cannot run, the action is allowed. This is the default for some Hermes settings and is explicitly changed in the guide.

## Host

The physical or virtual Ubuntu machine that runs Docker, ClawShell, Pipelock, and the firewall. The agent container runs on the host.

## Image digest

A cryptographic hash that uniquely identifies a container image. Pinning the base image by digest makes builds reproducible and prevents supply-chain surprises.

## Inference

Running a language model to produce text completions. Inference can happen remotely via an API provider or locally via vLLM inside the container.

## Isolated bridge (`agentnet`)

A custom Docker network (`agentnet`) with no direct route to the internet. The Hermes container is attached only to this network.

## LAN (Local Area Network)

The local private network the host is attached to (for example, `192.168.x.x`). The firewall rules block the agent container from reaching LAN hosts.

## MCP (Model Context Protocol)

A protocol that lets agents use external tools and data sources. MCP servers can be proxied through Pipelock so their traffic is inspected.

## Metadata endpoint

A cloud-provider API reachable at a link-local address such as `169.254.169.254`. It can expose host credentials, so the firewall blocks the container from reaching it.

## Namespace

A Linux kernel feature that isolates process IDs, network interfaces, mounts, and other resources. Docker uses namespaces to isolate containers.

## NVIDIA Container Toolkit

Software that registers the NVIDIA runtime with Docker and wires GPU devices into containers. It is a thin shim over the host NVIDIA driver.

## NO_PROXY

An environment variable listing destinations that should not use the HTTP(S) proxy. The guide sets `NO_PROXY=172.30.0.1` so LLM calls go directly to ClawShell instead of through Pipelock.

## Pipelock

The host-side egress proxy and DLP layer. All non-ClawShell HTTPS traffic from the agent is forced through Pipelock, which applies allowlists, body scanning, and signed audit receipts.

## Privilege escalation

Gaining more privileges than intended, for example via a setuid binary. Hardening flags like `--security-opt no-new-privileges` and `--cap-drop ALL` prevent this.

## Read-only rootfs

A container filesystem that cannot be modified at runtime. The Hermes container uses `--read-only`; temporary writes go to `tmpfs` mounts.

## SBOM (Software Bill of Materials)

A machine-readable inventory of packages and libraries inside an image. The guide generates one with Trivy in SPDX-JSON format.

## Seccomp

A Linux kernel feature that filters which syscalls a process can make. Docker applies a default seccomp profile that blocks dangerous syscalls.

## Skills

Hermes extensions that add tools or capabilities. Skills can run commands or access the network, which is why the guide scans them and limits container privileges.

## SSRF (Server-Side Request Forgery)

An attack where a program is tricked into making requests to internal or restricted destinations. The firewall rules block SSRF attempts from the container to metadata endpoints and private IP ranges.

## systemd

The init system and service manager on Ubuntu. The guide uses systemd units to start and persist ClawShell, Pipelock, and the firewall rules.

## Tirith

A pre-execution command scanner in Hermes. It checks commands before they run and can block dangerous patterns. The guide enables it in fail-closed mode.

## Trivy

A vulnerability scanner. The guide uses Trivy to scan the Hermes image for HIGH and CRITICAL vulnerabilities and to generate an SBOM.

## vLLM

A local inference server. The optional local-inference path runs vLLM inside the container so prompts never leave the host.

## Virtual key

A token the agent holds that is meaningless without ClawShell. It maps to a real provider key on the host and can be revoked in one step.

---

← Back to [README](./README.md)
