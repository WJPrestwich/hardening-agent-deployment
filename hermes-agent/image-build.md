# Build the hardened Hermes image

This phase turns the verified Hermes installer into a hardened, deployable container image. By the end of this section you will have:

- The Hermes installer downloaded on the host from the official release page.
- A minimal `Dockerfile.hermes` that runs Hermes as a non-root user with the CUDA runtime.
- A built and tagged image (`hermes-guest:${HERMES_VERSION}` and `hermes-guest:latest`).

The next phase, [Scan the hardened Hermes image](./image-scan.md), adds vulnerability scanning, triage, an SBOM, and a tarball for promotion.

Hermes runs as a non-root user inside a minimal image. **The default deployment uses an API provider** (brokered by ClawShell), so the image only needs Hermes and the CUDA runtime for optional GPU workloads. Local inference is covered separately in [Local vLLM inference](./local-vllm-inference.md).

> **Version placeholders.** Throughout the guide `HERMES_VERSION=X.Y.Z` means "replace with the real Hermes release version you verified." Use the same value everywhere (build, tag, run, and operations).

Build on a machine/network you trust. Do not download installers inside the Dockerfile; fetch them on the host first, then `COPY` them in. This removes the build-time `curl | bash` supply-chain vector and makes the build reproducible.

## Download the Hermes installer on the host

Check the [Hermes releases page](https://hermes-agent.nousresearch.com/) for the current installer URL and version, then download it:

```bash
mkdir -p ~/hermes-build && cd ~/hermes-build

HERMES_VERSION=X.Y.Z              # replace with the Hermes release you verified
curl -fsSL -o install-hermes.sh \
  "https://hermes-agent.nousresearch.com/install-${HERMES_VERSION}.sh"
```

## Limit the build context

Save [`assets/dot-dockerignore`](./assets/dot-dockerignore) as `.dockerignore` in your build directory:

```bash
cp hermes-agent/assets/dot-dockerignore .dockerignore
```

## Dockerfile

Save [`assets/Dockerfile.hermes`](./assets/Dockerfile.hermes) as `Dockerfile.hermes` in your build directory:

```bash
cp hermes-agent/assets/Dockerfile.hermes Dockerfile.hermes
```

The Dockerfile pins the NVIDIA base image by digest. Look up the current digest for the tag and paste it into the `FROM` line:

```bash
docker buildx imagetools inspect \
  nvidia/cuda:12.6.3-runtime-ubuntu24.04 \
  --format '{{json .Manifest.Digest}}'

# or, if you have already pulled the image:
docker inspect --format='{{index .RepoDigests 0}}' nvidia/cuda:12.6.3-runtime-ubuntu24.04
```

Both commands print a `sha256:...` value. Copy that value into the `FROM` line of `Dockerfile.hermes`, replacing `sha256:<paste-base-image-digest>`.

## Build and tag the image

```bash
docker build -t hermes-guest:${HERMES_VERSION} -f Dockerfile.hermes .
docker tag hermes-guest:${HERMES_VERSION} hermes-guest:latest
```

---

← Previous: [Setup Pipelock](./pipelock.md) | Next: [Scan the hardened Hermes image](./image-scan.md) →
