#!/bin/bash
# benchmark_speedrun.sh — quick tok/s benchmark against a running llama-server
#
# Usage:
#   bash scripts/benchmark_speedrun.sh [port] [host]
#
# Examples:
#   bash scripts/benchmark_speedrun.sh           # port 8080, localhost
#   bash scripts/benchmark_speedrun.sh 9090
#   bash scripts/benchmark_speedrun.sh 8080 compute-node-01

set -e

PORT="${1:-8080}"
HOST="${2:-localhost}"
BASE="http://$HOST:$PORT"

PROMPT="Explain the architecture of a Mixture-of-Experts language model in detail, covering how expert routing works, how experts are trained, and the tradeoffs between number of experts and model quality."

echo "=========================================="
echo "llama.cpp Speedrun Benchmark"
echo "=========================================="
echo "Target: $BASE"
echo "Date:   $(date)"
echo ""

# ── Health check ──
echo "Checking /health..."
HEALTH=$(curl -sf "$BASE/health" 2>/dev/null || true)
if [ -z "$HEALTH" ]; then
    echo "ERROR: server not responding at $BASE"
    echo "       Is the server running? Check: sbatch server-speedrun-rtx3070.sbatch"
    exit 1
fi
echo "  Response: $HEALTH"
echo ""

# ── Chat completions benchmark ──
echo "Running /v1/chat/completions benchmark..."
echo "  Prompt: $(echo "$PROMPT" | head -c 80)..."
echo ""

PAYLOAD=$(printf '{"model":"local","messages":[{"role":"user","content":"%s"}],"max_tokens":512,"stream":false,"temperature":0.0}' \
    "$(echo "$PROMPT" | sed 's/"/\\"/g')")

T_START=$(date +%s%3N)

RESPONSE=$(curl -sf \
    -X POST "$BASE/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" 2>/dev/null)

T_END=$(date +%s%3N)
ELAPSED_MS=$(( T_END - T_START ))
ELAPSED_S=$(echo "scale=2; $ELAPSED_MS / 1000" | bc)

if [ -z "$RESPONSE" ]; then
    echo "ERROR: empty response from /v1/chat/completions"
    exit 1
fi

# Parse fields — requires jq
if command -v jq &>/dev/null; then
    COMPLETION_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.completion_tokens // "unknown"')
    PROMPT_TOKENS=$(echo "$RESPONSE"    | jq -r '.usage.prompt_tokens // "unknown"')
    CONTENT=$(echo "$RESPONSE"          | jq -r '.choices[0].message.content // ""' | head -c 300)

    echo "  Prompt tokens:     $PROMPT_TOKENS"
    echo "  Completion tokens: $COMPLETION_TOKENS"
    echo "  Wall time:         ${ELAPSED_S}s"
    echo ""

    if [[ "$COMPLETION_TOKENS" =~ ^[0-9]+$ ]] && [ "$ELAPSED_MS" -gt 0 ]; then
        TOKS_PER_S=$(echo "scale=2; $COMPLETION_TOKENS / ($ELAPSED_MS / 1000)" | bc)
        echo "  ┌─────────────────────────────────┐"
        echo "  │  tok/s  ≈  $TOKS_PER_S"
        echo "  └─────────────────────────────────┘"
    fi
    echo ""
    echo "  Response preview:"
    echo "  ---"
    echo "$CONTENT"
    echo "  ---"
else
    echo "  Wall time: ${ELAPSED_S}s  (install jq for token counts)"
    echo ""
    echo "  Raw response (truncated):"
    echo "$RESPONSE" | head -c 500
fi

echo ""
echo "=========================================="
echo "Done. Record results in results/rtx3070-qwen3-30b-a3b-speedrun.md"
echo "=========================================="
