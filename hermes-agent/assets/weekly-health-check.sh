#!/usr/bin/env bash
# Weekly health check for the hardened Hermes stack.
# Run from the host as a user who can use docker and sudo for systemd/iptables.
# Exit code 0 if all checks pass, non-zero otherwise.

set -euo pipefail

HERMES_NAME="${HERMES_NAME:-hermes}"

PASS=0
FAIL=0
SKIP=0

ok() {
  echo "[PASS] $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "[FAIL] $1"
  FAIL=$((FAIL + 1))
}

skip() {
  echo "[SKIP] $1"
  SKIP=$((SKIP + 1))
}

# --- Services ---
if sudo systemctl is-active agentnet-firewall pipelock clawshell >/dev/null 2>&1; then
  ok "systemd services (agentnet-firewall, pipelock, clawshell) are active"
else
  fail "one or more systemd services are not active"
fi

# --- Firewall rules ---
if sudo iptables -L DOCKER-USER -n -v | grep -qE 'AGENT-(FORWARD|INPUT)-DROP|172\.30\.0\.0/24'; then
  ok "DOCKER-USER contains agentnet drop rules"
else
  fail "DOCKER-USER agentnet drop rules are missing"
fi

# --- Pipelock audit trail ---
if sudo ls -lt /var/lib/pipelock/evidence/ 2>/dev/null | head -n 5 | grep -q 'evidence-'; then
  ok "recent Pipelock evidence files exist"
else
  fail "no recent Pipelock evidence files found"
fi

# --- ClawShell health (not used in local-vLLM mode) ---
image=$(docker inspect "${HERMES_NAME}" --format='{{.Config.Image}}' 2>/dev/null || true)
if [[ "${image}" == hermes-guest:vllm-* ]]; then
  skip "ClawShell stats endpoint (vLLM mode)"
elif curl -fs http://127.0.0.1:18790/admin/stats >/dev/null 2>&1; then
  ok "ClawShell stats endpoint is reachable"
else
  fail "ClawShell stats endpoint is not reachable"
fi

# --- Container health ---
if docker ps --filter name="${HERMES_NAME}" --format '{{.Names}}' | grep -qx "${HERMES_NAME}"; then
  ok "${HERMES_NAME} container is running"
else
  fail "${HERMES_NAME} container is not running"
fi

if docker exec "${HERMES_NAME}" nvidia-smi >/dev/null 2>&1; then
  ok "${HERMES_NAME} container can see the GPU"
else
  fail "${HERMES_NAME} container cannot see the GPU"
fi

# --- Summary ---
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"

if [[ ${FAIL} -gt 0 ]]; then
  exit 1
fi
