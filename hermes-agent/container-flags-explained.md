# Container security flags explained

This page explains the hardened `docker run` flags used in [Run the container](./run-the-container.md).

## Flag rationale

- `--init` — reaps zombie processes and handles signals cleanly.
- `--cap-drop ALL` — Hermes needs no Linux capabilities; drop them all. Add back only if something concrete breaks (it shouldn't).
- `--security-opt no-new-privileges` — no setuid escalation.
- `--read-only` + `--tmpfs /tmp` and `/run` — immutable rootfs; temporary writes go to tmpfs. `noexec` is set explicitly even though Docker often adds it by default.
- Named volume for `~/.hermes` (state) so it persists and stays writable under the read-only rootfs.
- **`config.yaml` mounted `readonly`** — this is the important one. Hermes' security settings (`tirith_*`, `terminal.backend`, `model.base_url`) otherwise live in the writable state volume, so a compromised agent could simply edit them to turn Tirith off or repoint the model at an attacker endpoint. Mounting the config file read-only from a root-owned host file means the agent cannot rewrite its own guardrails. The rest of `~/.hermes` stays writable for legitimate state; only the config is frozen.
- `--pids-limit`, `--memory`, `--cpus` — cap fork-bomb / resource-exhaustion blast radius. Adjust these to your hardware and workload.
- `NO_PROXY=172.30.0.1` — LLM calls go straight to ClawShell instead of being double-proxied through Pipelock. (ClawShell does the content inspection on that channel — see the ClawShell section.)
- `--restart unless-stopped` — keeps the agent up across host reboots. `HERMES_RESTART=no` is used for the first smoke test so a bad config doesn't loop forever.

> On Ubuntu, Docker's default AppArmor profile (`docker-default`) is already applied, so we don't need to set it explicitly. If you have a custom AppArmor profile for Hermes, use `--security-opt apparmor=your-profile` instead.

---

← Back to [Run the container](./run-the-container.md)
