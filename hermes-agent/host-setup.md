# Host setup

This phase installs Docker Engine and the NVIDIA Container Toolkit on the Ubuntu host, then proves the GPU is visible inside a throwaway container. By the end of this section you will have:

- Docker Engine and the build plugins installed from Docker's official repository.
- The NVIDIA Container Toolkit registered as a Docker runtime.
- A successful `nvidia-smi` run inside a test container.

The next section will merge hardening keys into the same `/etc/docker/daemon.json` that the NVIDIA toolkit creates here.

## Install Docker Engine

Install Docker from Docker's official [apt repository](https://docs.docker.com/engine/install/ubuntu/). The steps below are a condensed version of the official guide.

Add Docker's GPG key and apt repository, then install Docker Engine:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
sudo tee /etc/apt/sources.list.d/docker.list >/dev/null <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable
EOF

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

This writes the apt source with a `tee` here-document instead of a multi-line `echo`, which is easier to read and less likely to break when copied.

If you want to run `docker` commands as a non-root user:

```bash
sudo usermod -aG docker $USER
# Then log out and back in (or run `newgrp docker`) for the group change to take effect.
```

## Install the NVIDIA Container Toolkit

See the [official install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) for current details.

Add the NVIDIA repository and install the toolkit:

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
```

Register the NVIDIA runtime with Docker and restart the daemon:

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

Verify the runtime was registered:

```bash
python3 -m json.tool /etc/docker/daemon.json | grep -A2 '"nvidia"'
```

You should see a `runtimes.nvidia` block. If the file is missing or the block is absent, GPU containers will not work.

## Verify GPU access inside a container

Run a throwaway CUDA container to confirm the driver and toolkit wiring work. Replace the tag with a current CUDA + Ubuntu LTS base image that matches your host driver.

```bash
docker run --rm --gpus all nvidia/cuda:12.6.3-base-ubuntu24.04 nvidia-smi
```

If this prints the GPU info table, the hardest part of a microVM-based build is already behind you.

> The container's CUDA toolkit version must be supported by the host driver. Newer drivers are backward-compatible with older CUDA containers, but a newer CUDA container requires a minimum driver version. Check the [CUDA compatibility matrix](https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html) and the [current `nvidia/cuda` tags](https://hub.docker.com/r/nvidia/cuda/tags) before picking a base image.

---

← Previous: [Prerequisites](./prerequisites.md) | Next: [Docker daemon hardening](./docker-daemon-hardening.md) →
