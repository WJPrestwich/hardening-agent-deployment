#!/usr/bin/env bash
# Verify each security layer of the hardened Hermes stack.
# Run this from the host after starting the hermes container.
# Override the container name with HERMES_NAME (default: hermes).

set -euo pipefail

HERMES_NAME="${HERMES_NAME:-hermes}"
PROXY="${PROXY:-http://172.30.0.1:8888}"
CLAWSHELL_URL="${CLAWSHELL_URL:-http://172.30.0.1:18790}"

PASS=0
FAIL=0

run() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "[PASS] ${name}"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] ${name}"
    FAIL=$((FAIL + 1))
  fi
}

# 1. Runtime posture
readonly_output=$(docker inspect "${HERMES_NAME}" --format '{{.HostConfig.ReadonlyRootfs}} {{.HostConfig.CapDrop}}' 2>/dev/null || true)
if [[ "${readonly_output}" == "true [ALL]" ]]; then
  echo "[PASS] container runs with --read-only and --cap-drop ALL"
  PASS=$((PASS + 1))
else
  echo "[FAIL] container runtime posture: ${readonly_output}"
  FAIL=$((FAIL + 1))
fi

uid=$(docker exec "${HERMES_NAME}" id -u 2>/dev/null || true)
if [[ "${uid}" == "1000" ]]; then
  echo "[PASS] container user is hermes (uid 1000)"
  PASS=$((PASS + 1))
else
  echo "[FAIL] container user is not hermes: uid=${uid}"
  FAIL=$((FAIL + 1))
fi

capeff=$(docker exec "${HERMES_NAME}" grep CapEff /proc/self/status 2>/dev/null | awk '{print $2}' || true)
if [[ "${capeff}" == "0000000000000000" ]]; then
  echo "[PASS] effective capabilities are empty"
  PASS=$((PASS + 1))
else
  echo "[FAIL] effective capabilities: ${capeff}"
  FAIL=$((FAIL + 1))
fi

nonewprivs=$(docker exec "${HERMES_NAME}" grep NoNewPrivs /proc/1/status 2>/dev/null | awk '{print $2}' || true)
if [[ "${nonewprivs}" == "1" ]]; then
  echo "[PASS] no-new-privileges is set"
  PASS=$((PASS + 1))
else
  echo "[FAIL] no-new-privileges: ${nonewprivs}"
  FAIL=$((FAIL + 1))
fi

run "root filesystem is read-only" \
  docker exec "${HERMES_NAME}" bash -c '! touch /etc/pwned 2>/dev/null'

# 2. GPU access
run "nvidia-smi works" \
  docker exec "${HERMES_NAME}" nvidia-smi

# 3. DNS and direct internet egress are blocked
run "DNS lookup is blocked" \
  sh -c "! docker exec '${HERMES_NAME}' getent hosts example.com >/dev/null 2>&1"

run "direct HTTPS is blocked" \
  sh -c "! docker exec '${HERMES_NAME}' bash -c 'curl -m 5 https://example.com' >/dev/null 2>&1"

# 4. Pipelock allowlist
run "allowed destination (github.com) via proxy" \
  docker exec "${HERMES_NAME}" bash -c "curl -m 5 -x ${PROXY} -o /dev/null -s -w '%{http_code}' https://github.com | grep -q '^20'"

run "non-allowed destination is denied by Pipelock" \
  sh -c "! docker exec '${HERMES_NAME}' bash -c 'curl -m 5 -x ${PROXY} -o /dev/null -s -w \"%{http_code}\" https://example.com | grep -qE \"^(20|30)\"' >/dev/null 2>&1"

# 5. Pipelock DLP
run "AWS key in request body is blocked" \
  sh -c "! docker exec '${HERMES_NAME}' bash -c 'curl -m 5 -x ${PROXY} -d key=AKIA1234567890ABCDEF -o /dev/null -s -w \"%{http_code}\" https://github.com | grep -qE \"^(20|30)\"' >/dev/null 2>&1"

if sudo bash -c 'ls /var/lib/pipelock/evidence/evidence-*.jsonl >/dev/null 2>&1'; then
  echo "[PASS] Pipelock evidence receipts exist"
  PASS=$((PASS + 1))
else
  echo "[FAIL] no Pipelock evidence receipts found"
  FAIL=$((FAIL + 1))
fi

# 6. Config is frozen
run "Hermes config is read-only inside the container" \
  sh -c "! docker exec '${HERMES_NAME}' bash -c 'echo x >> ~/.hermes/config.yaml' 2>/dev/null"

if docker exec "${HERMES_NAME}" grep -A4 'security:' ~/.hermes/config.yaml 2>/dev/null | grep -q 'tirith_enabled: true'; then
  echo "[PASS] Tirith is enabled in config"
  PASS=$((PASS + 1))
else
  echo "[FAIL] Tirith enabled not found in config"
  FAIL=$((FAIL + 1))
fi

if docker exec "${HERMES_NAME}" grep -A4 'security:' ~/.hermes/config.yaml 2>/dev/null | grep -q 'tirith_fail_open: false'; then
  echo "[PASS] Tirith is fail-closed"
  PASS=$((PASS + 1))
else
  echo "[FAIL] Tirith fail-closed not found in config"
  FAIL=$((FAIL + 1))
fi

# 7. Metadata and LAN isolation
run "cloud metadata endpoint is unreachable" \
  sh -c "! docker exec '${HERMES_NAME}' bash -c 'curl -m 5 http://169.254.169.254/latest/meta-data/' >/dev/null 2>&1"

LAN_GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n1 || true)
if [[ -n "${LAN_GATEWAY}" ]]; then
  run "LAN gateway (${LAN_GATEWAY}) is unreachable" \
    sh -c "! docker exec '${HERMES_NAME}' bash -c 'curl -m 5 http://${LAN_GATEWAY}/' >/dev/null 2>&1"
else
  echo "[SKIP] LAN gateway check (no default route found)"
fi

# 8. ClawShell brokering (optional; ClawShell may not be used in vLLM mode)
if curl -s "${CLAWSHELL_URL}/admin/stats" >/dev/null 2>&1; then
  response=$(docker exec "${HERMES_NAME}" bash -c "curl -m 5 -H 'Authorization: Bearer vk-hermes-001' ${CLAWSHELL_URL}/v1/models" 2>/dev/null || true)
  if [[ -n "${response}" ]]; then
    echo "[PASS] ClawShell /v1/models responded"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] ClawShell /v1/models did not respond"
    FAIL=$((FAIL + 1))
  fi
else
  echo "[SKIP] ClawShell health check (not reachable; expected in local-vLLM mode)"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [[ ${FAIL} -gt 0 ]]; then
  exit 1
fi
