# Run the container

This phase starts the hardened Hermes container on the isolated `agentnet` bridge. By the end of this section you will have:

- A `hermes-run` wrapper script on the host that captures the long `docker run` command.
- A running `hermes` container using the scanned image tag.
- A smoke test confirming startup logs, GPU visibility, and the unprivileged user.
- The container configured to restart automatically across host reboots.

The hardened `docker run` command is long. Put it in a wrapper script once, then start Hermes with environment variables.

## Create the `hermes-run` helper

Save [`assets/hermes-run`](./assets/hermes-run) to `/usr/local/bin/hermes-run`:

```bash
sudo install -m 0755 hermes-agent/assets/hermes-run /usr/local/bin/hermes-run
```

## Start Hermes for the first time

Use the scanned tag and disable restart until you have confirmed the container starts cleanly:

```bash
export HERMES_VERSION=X.Y.Z   # replace with the tag you built and scanned
HERMES_RESTART=no hermes-run
```

If `hermes-run` complains that a container named `hermes` already exists, remove it and try again:

```bash
docker stop hermes && docker rm hermes
HERMES_RESTART=no HERMES_VERSION=X.Y.Z hermes-run
```

## Smoke test

Watch the startup log until Hermes is running, then verify GPU access and the container identity:

```bash
docker logs hermes -f        # watch startup; Ctrl-C once it is running
```

You should see lines similar to:

```
Hermes starting...
Loaded config from /home/hermes/.hermes/config.yaml
Tirith enabled, fail_open=false
Connected to model endpoint http://172.30.0.1:18790/v1
Agent ready.
```

Exact log messages depend on the Hermes version; the key signal is that the process stays up and does not exit with an error.

In a second terminal:

```bash
docker exec hermes nvidia-smi
docker exec hermes id
```

Expected: `nvidia-smi` prints your GPU, and `id` shows `uid=1000(hermes)`.

### If `nvidia-smi` fails

Most of the time `nvidia-container-toolkit` handles permissions automatically and `nvidia-smi` just works. If it fails with a permission/NVML error, the container user's group does not match the host GPU device's group. On Ubuntu, NVIDIA devices are typically owned by the `video` and/or `render` groups.

Check the device groups on the host:

```bash
ls -l /dev/nvidia*
```

Then add the relevant GID when you run the container. Edit `/usr/local/bin/hermes-run` and add one or both of these flags to the `docker run` command:

```bash
--group-add $(getent group video | cut -d: -f3)
--group-add $(getent group render | cut -d: -f3)
```

Recreate the container and rerun the smoke test:

```bash
docker stop hermes && docker rm hermes
HERMES_RESTART=no HERMES_VERSION=X.Y.Z hermes-run
```

## Start for normal operation

After the smoke test succeeds, run the container with the default restart policy:

```bash
export HERMES_VERSION=X.Y.Z
hermes-run
```

For an explanation of each hardened flag, see [Container security flags explained](./container-flags-explained.md).

---

← Previous: [Scan the hardened Hermes image](./image-scan.md) | Next: [Configure Hermes](./configure-hermes.md) →
