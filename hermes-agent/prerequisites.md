# Prerequisites

This phase prepares the bare-metal Ubuntu host. By the end of this section you will have:

- A supported NVIDIA GPU with the host driver installed.
- `nvidia-smi` returning GPU info on the host.
- The base tooling (`curl`, `wget`, `jq`) installed.

Everything that follows depends on these checks passing, so do not skip them.

## Hardware and driver

You need a machine with a supported NVIDIA GPU. The GPU stays usable by the host and can be shared across containers.

### Check your GPU

```bash
lspci | grep -i nvidia
```

If you do not see an NVIDIA device, stop here and resolve the hardware detection problem before continuing.

### Install the NVIDIA driver

Install the NVIDIA driver on the host first. The NVIDIA Container Toolkit is only a thin shim over the host driver, so if `nvidia-smi` fails on the host, no container will see a GPU. NVIDIA recommends installing the driver through your distribution's package manager; on Ubuntu the `ubuntu-drivers` tool is the simplest path.

See the official documentation for the current supported GPUs, driver versions, and install steps:

- [NVIDIA Driver Installation Quickstart Guide](https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/introduction.html)
- [Ubuntu NVIDIA driver docs](https://ubuntu.com/server/docs/how-to/graphics/install-nvidia-drivers)
- [CUDA release notes and driver compatibility](https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html)

```bash
# Install the recommended driver for your GPU and reboot
sudo ubuntu-drivers install
sudo reboot

# This must succeed on the host before continuing
nvidia-smi
```

If `ubuntu-drivers install` does not work for your setup, use the official NVIDIA docs to pick and install the correct driver package for your GPU and Ubuntu version rather than copying a pinned version number from this guide.

## Base tooling

Install the small set of command-line tools the rest of the guide uses for downloads and JSON parsing:

```bash
sudo apt-get update
sudo apt-get install -y curl wget jq
```

---

← Previous: [Why this guide](./why-this-approach.md) | Next: [Host setup](./host-setup.md) →
