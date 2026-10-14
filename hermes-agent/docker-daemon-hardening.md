# Docker daemon hardening

This phase hardens the Docker daemon defaults that apply to every container on the host. By the end of this section you will have:

- A single `/etc/docker/daemon.json` that contains both the NVIDIA runtime and the hardening keys.
- A restarted Docker daemon that enforces `no-new-privileges`, disables inter-container communication on the default bridge, routes published ports through iptables, and caps log size.

`nvidia-ctk` added a `runtimes` block to `/etc/docker/daemon.json`. The hardening keys below must be *merged* into that file, not pasted over it — if you overwrite `runtimes`, GPU access breaks.

The provided [`assets/daemon.json`](./assets/daemon.json) already contains both the NVIDIA runtime and the hardening keys. If you have no existing daemon config, copy it directly:

```bash
sudo cp hermes-agent/assets/daemon.json /etc/docker/daemon.json
```

If you already have a custom `/etc/docker/daemon.json`, back it up first and merge the new keys in instead of overwriting. Use [`assets/merge-docker-daemon-config.py`](./assets/merge-docker-daemon-config.py):

```bash
sudo python3 hermes-agent/assets/merge-docker-daemon-config.py
```

You can preview the merge with `--dry-run`:

```bash
sudo python3 hermes-agent/assets/merge-docker-daemon-config.py --dry-run
```

The script backs up the existing config, recursively merges the asset, validates the JSON, and confirms the NVIDIA runtime is still present.

Restart Docker to load the new defaults:

```bash
sudo systemctl restart docker
```

## What each key does in this stack

- `no-new-privileges`: blocks privilege escalation via setuid binaries inside any container.
- `icc: false`: disables inter-container communication on the default bridge.
- `userland-proxy: false`: routes published-port traffic through iptables rather than a userspace proxy, giving cleaner firewall behavior.
- `live-restore`: keeps containers running across Docker daemon restarts.
- `log-opts`: caps log file growth so a noisy agent can't fill the disk.

Two things to keep in mind:

- `icc: false` only applies to the default bridge. The custom `agentnet` bridge we create in the next section is not covered by it, which is why we keep only the agent container on that network.
- Docker already enables a default seccomp profile and the `docker-default` AppArmor profile on Ubuntu. The container-level flags in the run command add the rest.

### Advanced: user namespaces (`userns-remap`)

Mapping container-root to an unprivileged host UID (so root inside the container is not root on the host) is excellent hardening, but it is a global daemon setting and has a long history of friction with the NVIDIA runtime and `--gpus`. Test it in isolation; if GPU access breaks, don't fight it — rely instead on running the container as a **non-root user** plus `--cap-drop ALL` and `no-new-privileges`, which give most of the benefit and are GPU-safe. This guide takes the non-root-user route by default.

For the full hardening checklist, see the [Docker daemon configuration reference](https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file) and the [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker).

---

← Previous: [Host setup](./host-setup.md) | Next: [Create the agent bridge](./network-isolation.md) →
