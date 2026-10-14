#!/usr/bin/env bash
# Start vLLM inside the Hermes container.
# The caller can override the container name with HERMES_NAME (default: hermes).

HERMES_NAME="${HERMES_NAME:-hermes}"

docker exec "${HERMES_NAME}" bash -c \
  'mkdir -p /tmp/hf /tmp/vllm-logs && nohup vllm serve /models/Llama-3.1-8B-Instruct \
     --host 127.0.0.1 --port 8000 \
     --gpu-memory-utilization 0.85 \
     --max-model-len 8192 \
     > /tmp/vllm-logs/vllm.log 2>&1 &'

# Poll until healthy (adjust loop count if your model is large)
healthy=0
for i in {1..60}; do
  if docker exec "${HERMES_NAME}" curl -fs http://127.0.0.1:8000/health >/dev/null 2>&1; then
    echo "vLLM is healthy"
    healthy=1
    break
  fi
  echo "waiting for vLLM... ($i)"
  sleep 5
done

if [[ "$healthy" -ne 1 ]]; then
  echo "vLLM did not become healthy; last 50 log lines:"
  docker exec "${HERMES_NAME}" tail -n 50 /tmp/vllm-logs/vllm.log
  exit 1
fi
