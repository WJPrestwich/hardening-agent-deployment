#!/usr/bin/env bash
# Restore the Hermes agent state and host configs from a backup.

set -euo pipefail

CONTAINER="${CONTAINER:-hermes}"
BACKUP_DIR="${BACKUP_DIR:-/backup}"
HERMES_VERSION="${HERMES_VERSION:-}"

usage() {
  echo "Usage: BACKUP_DIR=/backup HERMES_VERSION=X.Y.Z $(basename "$0") <date-suffix>"
  echo ""
  echo "Restores host configs and the hermes-state volume from files named:"
  echo "  ${BACKUP_DIR}/config.yaml-<date-suffix>"
  echo "  ${BACKUP_DIR}/clawshell.toml-<date-suffix>"
  echo "  ${BACKUP_DIR}/hermes-state-<date-suffix>.tar.gz"
  exit 1
}

if [[ $# -ne 1 ]]; then
  usage
fi

DATE_SUFFIX="$1"

if [[ -z "${HERMES_VERSION}" ]]; then
  echo "ERROR: set HERMES_VERSION to the scanned image tag you want to run." >&2
  exit 1
fi

CONFIG_BACKUP="${BACKUP_DIR}/config.yaml-${DATE_SUFFIX}"
CLAWSHELL_BACKUP="${BACKUP_DIR}/clawshell.toml-${DATE_SUFFIX}"
STATE_BACKUP="${BACKUP_DIR}/hermes-state-${DATE_SUFFIX}.tar.gz"

for f in "${CONFIG_BACKUP}" "${CLAWSHELL_BACKUP}" "${STATE_BACKUP}"; do
  if [[ ! -f "${f}" ]]; then
    echo "ERROR: backup file not found: ${f}" >&2
    exit 1
  fi
done

echo "Restoring from:"
echo "  config:  ${CONFIG_BACKUP}"
echo "  clawshell: ${CLAWSHELL_BACKUP}"
echo "  state:   ${STATE_BACKUP}"

# 1. Stop and remove the existing container (if any)
echo "[1/4] Stopping and removing container '${CONTAINER}'..."
docker stop "${CONTAINER}" >/dev/null 2>&1 || true
docker rm "${CONTAINER}" >/dev/null 2>&1 || true

# 2. Restore the host configs
echo "[2/4] Restoring host configs..."
sudo cp "${CONFIG_BACKUP}" /etc/hermes/config.yaml
sudo cp "${CLAWSHELL_BACKUP}" /etc/clawshell/clawshell.toml

# 3. Restore the hermes-state Docker volume from the tarball
echo "[3/4] Restoring hermes-state volume..."
docker volume rm hermes-state >/dev/null 2>&1 || true
docker volume create hermes-state >/dev/null
docker run --rm \
  -v hermes-state:/data \
  -v "${BACKUP_DIR}:/backup:ro" \
  alpine tar xzf "/backup/hermes-state-${DATE_SUFFIX}.tar.gz" -C /data

# 4. Restart the control-plane services and the container
echo "[4/4] Restarting services and container..."
sudo systemctl restart agentnet-firewall pipelock clawshell
HERMES_VERSION="${HERMES_VERSION}" hermes-run

echo ""
echo "Restore complete. Container '${CONTAINER}' is running from ${HERMES_VERSION}."
