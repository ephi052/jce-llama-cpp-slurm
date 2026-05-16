#!/bin/bash
#SBATCH --job-name=llama_server
#SBATCH --output=llama_server_%j.log
#SBATCH --error=llama_server_%j.log
#SBATCH --partition=main
# exlude 1080ti and 2080 nodes since they have insufficient GPU RAM for larger models
#SBATCH --exclude=HPC-GTX1080ti-[01,03-09],HPC-RTX2080-X8,HPC-RTX2080s-[01-03]
#SBATCH --gres=gpu:1
#SBATCH --time=7-00:00:00


# Default partition is main with an exclude list that avoids undersized nodes.
# Override at submit time, e.g.:
#   sbatch -p <partition> server.sbatch [model] [port] [parallel]

# Usage: sbatch server.sbatch [model] [port] [parallel]
# Examples:
#   sbatch server.sbatch                                            # defaults
#   sbatch server.sbatch Qwen/Qwen2.5-7B-Instruct-GGUF:Q4_K_M     # specific model
#   sbatch server.sbatch Qwen/Qwen2.5-7B-Instruct-GGUF:Q4_K_M 9090
#   sbatch server.sbatch Qwen/Qwen2.5-7B-Instruct-GGUF:Q4_K_M 8080 4
#
# Context per request = DEFAULT_CONTEXT_SIZE / parallel
# Defaults (env.sh): ctx-size=4096, parallel=1 → 4096 tokens per request
# See README.md for context/parallel tradeoff table

set -e

SCRIPT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
cd "$SCRIPT_DIR"
source env.sh

MODEL="${1:-$HF_MODEL}"
PORT="${2:-8080}"
PARALLEL="${3:-$DEFAULT_PARALLEL}"
HOST="0.0.0.0"
NODE=$(hostname)

# Validate inputs
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65535 ]; then
    echo "Error: PORT must be a number between 1024 and 65535 (got: '$PORT')"
    exit 1
fi
if ! [[ "$PARALLEL" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: PARALLEL must be a positive integer (got: '$PARALLEL')"
    exit 1
fi

EFFECTIVE_CTX=$(( DEFAULT_CONTEXT_SIZE / PARALLEL ))

echo "=========================================="
echo "llama.cpp OpenAI-Compatible Server"
echo "=========================================="
echo "Node:  $NODE"
echo "Port:  $PORT"
echo "Model: $MODEL"
echo "Cache: $LLAMA_CACHE"
echo "Parallel slots: $PARALLEL"
echo "Context per request: $EFFECTIVE_CTX"
echo ""
echo "Connect from your local machine:"
echo "  ssh -L $PORT:$NODE:$PORT $(whoami)@hpc-master"
echo "  or directly: http://$NODE:$PORT"
echo "  http://localhost:$PORT"
echo "  http://localhost:$PORT/v1/chat/completions"
echo "=========================================="
echo ""

$LLAMA_BIN_DIR/llama-server \
    -hf "$MODEL" \
    --host $HOST \
    --port $PORT \
    -ngl $DEFAULT_GPU_LAYERS \
    --ctx-size $DEFAULT_CONTEXT_SIZE \
    --parallel $PARALLEL \
    --cont-batching \
    -t 8 \
    --jinja
