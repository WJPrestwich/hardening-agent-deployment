# Verify manual checks

This page contains the individual commands behind [Verify each layer](./verify-each-layer.md). Run them if you want to inspect each control by hand rather than using the bundled script.

## 1. Runtime posture

Confirm the container was started with the hardened flags and is running as the unprivileged `hermes` user.

Check the Docker host-config flags:

```bash
docker inspect hermes --format '{{.HostConfig.ReadonlyRootfs}} {{.HostConfig.CapDrop}}'
```

Expected: `true [ALL]`

Check the effective process user and capabilities:

```bash
docker exec hermes id
docker exec hermes grep CapEff /proc/self/status
docker exec hermes grep NoNewPrivs /proc/1/status
```

Expected:

- `uid=1000(hermes) gid=1000(hermes)`
- `CapEff:	0000000000000000`
- `NoNewPrivs:	1`

Confirm the root filesystem is actually read-only at runtime:

```bash
docker exec hermes touch /etc/pwned 2>&1
```

Expected: `touch: cannot touch '/etc/pwned': Read-only file system`.

## 2. GPU access

Hermes needs the GPU for inference or for the CUDA runtime path used by some skills.

```bash
# Should print the NVIDIA GPU info table
docker exec hermes nvidia-smi
```

Expected: a table listing your GPU, driver version, and memory.

## 3. DNS and direct internet egress are blocked

The container has no direct resolver and no route to the internet.

DNS lookup should fail:

```bash
docker exec hermes getent hosts example.com
```

Expected: empty output and a non-zero exit code.

Direct HTTPS should also fail:

```bash
docker exec hermes curl -m 5 https://example.com
```

Expected: `Could not resolve host`, `Connection timed out`, or a timeout exit.

## 4. Pipelock allowlist

Allowed destinations via the proxy should succeed. Everything else should be denied.

Allowed destination (`github.com` should be in your Pipelock config):

```bash
docker exec hermes curl -m 5 -x http://172.30.0.1:8888 https://github.com
```

Expected: HTTP 200 response body or headers.

Non-allowed destination:

```bash
docker exec hermes curl -m 5 -x http://172.30.0.1:8888 https://example.com
```

Expected: HTTP 403 or a `denied by Pipelock` message.

## 5. Pipelock DLP

A fake AWS access key in the request body should be blocked and Pipelock should emit a signed evidence receipt.

```bash
docker exec hermes curl -x http://172.30.0.1:8888 -d "key=AKIA1234567890ABCDEF" https://github.com
```

Expected: block / 400 from Pipelock.

Then verify a new signed receipt exists:

```bash
sudo bash -c 'ls -lt /var/lib/pipelock/evidence/evidence-*.jsonl | head -n 5'
```

Expected: at least one recent evidence file.

## 6. ClawShell brokering

The container only knows a virtual key. ClawShell on the host swaps it for the real provider key.

Watch live traffic and confirm the swap:

```bash
sudo clawshell logs --follow
```

In another terminal, trigger a request through the LLM path. This hits ClawShell's OpenAI-compatible `/v1/models` endpoint using the container's virtual key:

```bash
docker exec hermes curl -m 5 -H "Authorization: Bearer vk-hermes-001" http://172.30.0.1:18790/v1/models
```

Expected: log lines showing the virtual key mapped to the real upstream key. The real key must not appear inside the container (`docker exec hermes env` should show only the virtual key).

## 7. Config is frozen

The config file is mounted read-only from a root-owned host file. The agent cannot rewrite its own guardrails.

```bash
docker exec hermes bash -c 'echo "x" >> ~/.hermes/config.yaml' 2>&1
```

Expected: `Read-only file system` or similar permission error.

Also confirm the security block is present:

```bash
docker exec hermes grep -A4 'security:' ~/.hermes/config.yaml
```

Expected: `tirith_enabled: true` and `tirith_fail_open: false`.

## 8. Metadata and LAN isolation

Cloud metadata endpoints and your LAN must be unreachable from the container.

```bash
# Cloud metadata endpoint (AWS-style example)
docker exec hermes curl -m 5 http://169.254.169.254/latest/meta-data/

# Your LAN gateway; adjust if your network uses a different subnet
LAN_GATEWAY=$(ip route | grep default | awk '{print $3}')
docker exec hermes curl -m 5 "http://${LAN_GATEWAY}/"
```

Expected: both commands time out or fail.

---

← Back to [Verify each layer](./verify-each-layer.md)
