# Scan the hardened Hermes image

This phase treats the built image as the deployable artifact: scan it for vulnerabilities, triage the results, generate an SBOM, and package it for promotion. By the end of this section you will have:

- A Trivy vulnerability scan with `HIGH`/`CRITICAL` findings triaged.
- An SPDX SBOM for the image.
- A tarball of the exact scanned image ready to move to a runtime host.

Do not rebuild from upstream installers on every deployment — that reintroduces the build-time supply-chain window. Build once in a trusted environment, scan it, and promote that exact image.

## Install Trivy

If Trivy is not already installed, add the Aqua Security apt repository and install it:

```bash
sudo apt-get install -y wget gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy
```

## Configure and run scans

A focused scan only reports `HIGH` and `CRITICAL` vulnerabilities that have a fix available:

```bash
trivy image \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  hermes-guest:${HERMES_VERSION}
```

## What to do with the results

Trivy prints one line per vulnerability with the package name, installed version, fixed version (if any), and severity. Use the **fixed-version** column to decide what to do next:

1. **No `HIGH`/`CRITICAL` findings** — proceed.
2. **Findings in the `nvidia/cuda` base image or core Ubuntu packages** — update the pinned digest and rebuild:
   ```bash
   # Look up the current digest for the base-image tag
   docker buildx imagetools inspect \
     nvidia/cuda:12.6.3-runtime-ubuntu24.04 \
     --format '{{json .Manifest.Digest}}'
   # or, if you have already pulled it:
   docker inspect --format='{{index .RepoDigests 0}}' nvidia/cuda:12.6.3-runtime-ubuntu24.04
   ```
   Copy the new `sha256:...` value into the `FROM` line of `Dockerfile.hermes`, then rebuild, rescan, and re-test GPU access before promoting the new image.
3. **Findings in dev tools you added** (e.g., `ffmpeg`, `rustc`, `postgresql-client`) — check whether a fixed package version is already available:
   ```bash
   apt-cache policy <package-name>
   ```
   If a fixed version exists, update the Dockerfile. If the tool is not actually needed by your skills, remove it instead of carrying the risk.
4. **Findings in Hermes or its installer** — update to a newer verified Hermes version and rebuild.
5. **No fixed version available** — the `--ignore-unfixed` flag already hides these. If a fixed-but-hard-to-remediate issue remains, document the exception (for example, a dated note in `.trivyignore`) rather than silently ignoring it.

Re-scan whenever you change the Dockerfile, the base image, or the Hermes installer.

For a detailed triage rubric, see [Vulnerability triage](./vulnerability-triage.md).

## Generate an SBOM

An SBOM (Software Bill of Materials) is a machine-readable inventory of every package and library inside the image. It lets you audit what you are deploying and quickly determine whether a newly announced vulnerable component is present:

```bash
trivy image \
  --format spdx-json \
  -o hermes-guest.spdx.json \
  hermes-guest:${HERMES_VERSION}
```

## Keep and run the exact image you scanned

For a personal but secure install, keep the scanned image under your control. Run from the version tag you scanned, not from `latest`, so you do not accidentally deploy an un-scanned rebuild:

```bash
# save the image as a tarball and move it to the runtime host
docker save hermes-guest:${HERMES_VERSION} | gzip > hermes-guest-${HERMES_VERSION}.tar.gz
# on the runtime host:
gunzip -c hermes-guest-${HERMES_VERSION}.tar.gz | docker load
```

---

← Previous: [Build the hardened Hermes image](./image-build.md) | Next: [Run the container](./run-the-container.md) →
