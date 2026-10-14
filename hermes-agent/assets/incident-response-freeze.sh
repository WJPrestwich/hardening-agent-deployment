#!/usr/bin/env bash
# Incident-response freeze playbook for a suspected Hermes compromise.
# Stops the container, preserves evidence, revokes the virtual key, and redeploys.

set -euo pipefail

CONTAINER="${CONTAINER:-hermes}"
DATE_STAMP="$(date +%Y%m%d)"
TIME_STAMP="$(date +%s)"
EVIDENCE_DIR="${EVIDENCE_DIR:-/secure/incident-${DATE_STAMP}-${TIME_STAMP}}"

echo "Incident response freeze starting for container '${CONTAINER}'"
echo "Evidence will be preserved under: ${EVIDENCE_DIR}"

# 1. Freeze the agent
echo "[1/5] Stopping container ${CONTAINER}..."
docker stop "${CONTAINER}" || true

# 2. Preserve evidence before anything else
echo "[2/5] Preserving evidence..."
sudo mkdir -p "${EVIDENCE_DIR}"

echo "  - committing forensics image"
docker commit "${CONTAINER}" "hermes-forensics-${TIME_STAMP}" || true

echo "  - copying Pipelock evidence"
sudo cp -a /var/lib/pipelock/evidence "${EVIDENCE_DIR}/" || true

echo "  - copying service logs"
sudo cp -a /var/log/pipelock "${EVIDENCE_DIR}/" || true
sudo cp -a /var/log/clawshell "${EVIDENCE_DIR}/" || true

echo "  - snapshotting hermes-state volume"
docker run --rm \
  -v hermes-state:/data \
  -v "${EVIDENCE_DIR}:/out" \
  alpine tar czf "/out/hermes-state.tar.gz" -C /data . || true

echo "  - copying host configs"
sudo cp -a /etc/hermes/config.yaml "${EVIDENCE_DIR}/" || true
sudo cp -a /etc/clawshell/clawshell.toml "${EVIDENCE_DIR}/" || true
sudo cp -a /etc/pipelock/config.yaml "${EVIDENCE_DIR}/" || true

echo "Evidence preserved under ${EVIDENCE_DIR}"
echo "Do not remove the container until you have confirmed the evidence is complete."

# 3. Revoke the compromised credential
# This step is interactive: the operator must edit clawshell.toml.
echo ""
echo "[3/5] Revoke the compromised credential:"
echo "  1. Edit /etc/clawshell/clawshell.toml and remove/comment the affected [[keys]] entry."
echo "  2. Press Enter when done to restart ClawShell."
read -r

sudo systemctl restart clawshell || true

# 4. Reconstruct what happened (instructions only)
echo ""
echo "[4/5] Reconstruct the incident:"
echo "  - Grep Pipelock evidence receipts for the virtual key and incident time window."
echo "  - Check: sudo clawshell logs --level error"
echo "  - Inspect the frozen state volume in ${EVIDENCE_DIR}/hermes-state.tar.gz"

# 5. Redeploy
HERMES_VERSION="${HERMES_VERSION:-}"
if [[ -z "${HERMES_VERSION}" ]]; then
  echo ""
  echo "[5/5] Redeploy: set HERMES_VERSION and run hermes-run, e.g.:"
  echo "  HERMES_VERSION=X.Y.Z docker rm ${CONTAINER} && HERMES_VERSION=X.Y.Z hermes-run"
else
  echo ""
  echo "[5/5] Redeploying with HERMES_VERSION=${HERMES_VERSION}..."
  docker rm "${CONTAINER}" || true
  hermes-run
fi

echo ""
echo "Incident response freeze complete."
