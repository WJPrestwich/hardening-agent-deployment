# Troubleshooting: host setup and Docker daemon

Problems with the host, GPU driver, Docker Engine, NVIDIA Container Toolkit, or `daemon.json`.

## General first steps

1. Check the logs of the failing service: `sudo journalctl -u <service> -n 100 --no-pager`.
2. Confirm the previous milestone still works (for example, do not debug the container until `docker run --rm --gpus all nvidia/cuda:... nvidia-smi` works on the host).
3. Verify file paths and permissions. Most host-side files should be owned by `root` or a dedicated service user, not by your normal login user.
4. Re-read the verification commands in [Verify each layer](./verify-each-layer.md). A failing verification test usually points directly at the broken layer.

## `nvidia-smi` fails on the host

- Confirm the GPU is detected: `lspci | grep -i nvidia`.
- Check that the correct kernel module is loaded: `lsmod | grep nvidia`.
- Look at the driver install log or dmesg: `sudo dmesg | grep -i nvidia | tail -20`.
- If you installed via `ubuntu-drivers install`, reboot and try again.

## Docker commands fail with "permission denied"

- If you added your user to the `docker` group, log out and back in (or run `newgrp docker`).
- Otherwise run commands with `sudo`.

## `docker run --rm --gpus all nvidia/cuda:... nvidia-smi` fails

- Verify the NVIDIA Container Toolkit is installed: `dpkg -l | grep nvidia-container-toolkit`.
- Verify the runtime is registered: `cat /etc/docker/daemon.json | grep -A2 nvidia`.
- Restart Docker after any daemon change: `sudo systemctl restart docker`.
- If you see a permission/NVML error, the container user may not have access to the GPU device group. On the host run `ls -l /dev/nvidia*` and note the group (usually `video` or `render`). When you run the Hermes container, add `--group-add $(getent group video | cut -d: -f3)` or the `render` equivalent.

## GPU access breaks after applying `daemon.json`

- This almost always means the NVIDIA `runtimes` block was overwritten. Back up `/etc/docker/daemon.json`, compare it with [`assets/daemon.json`](./assets/daemon.json), and merge the hardening keys into the file that `nvidia-ctk` created.
- After editing, validate JSON syntax: `python3 -m json.tool /etc/docker/daemon.json >/dev/null && echo "valid"`.
- Restart Docker: `sudo systemctl restart docker`.

## Docker fails to start after editing `daemon.json`

- Check the daemon log: `sudo journalctl -u docker -n 50 --no-pager`.
- Common causes: trailing commas, invalid keys, or quoting issues. `python3 -m json.tool` catches most of them before you restart.

---

← Back to [Troubleshooting](./troubleshooting.md)
