#!/bin/bash
#SBATCH --job-name=llama_speedrun
#SBATCH --output=speedrun_%j.log
#SBATCH --error=speedrun_%j.log
#SBATCH --partition=main
#SBATCH --exclude=HPC-GTX1080ti-[01,03-09],HPC-RTX2080-X8,HPC-RTX2080s-[01-03]
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=16
#SBATCH --mem=28G
#SBATCH --time=04:00:00

# RTX3070 speedrun server — tested with Qwen3-30B-A3B and Qwen3.6-35B-A3B
#
# Usage:
#   sbatch server-speedrun-rtx3070.sbatch
#
# Override any default at submit time:
#   MODEL_PATH=./models/my.gguf sbatch server-speedrun-rtx3070.sbatch
#   MODEL_HF=Qwen/Qwen3-35B-A22B-Instruct-GGUF:Q4_K_M sbatch server-speedrun-rtx3070.sbatch
#   N_CPU_MOE=38 CTX=32768 sbatch server-speedrun-rtx3070.sbatch   # Qwen3-30B-A3B balanced upstream
#   MODEL_PATH=./models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf N_CPU_MOE=34 CTX=131072 sbatch server-speedrun-rtx3070.sbatch
#   MODEL_PATH=./models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf N_CPU_MOE=32 CTX=131072 sbatch server-speedrun-rtx3070.sbatch
#
# See results/rtx3070-qwen3-30b-a3b-speedrun.md and results/rtx3070-qwen36-35b-a3b-speedrun.md.

set -e

SCRIPT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
cd "$SCRIPT_DIR"
source env.sh

# ── Model config ──
# Prefer local GGUF for reproducible benchmarks.
# Set MODEL_HF to use llama-server's built-in HF download instead.
MODEL_PATH="${MODEL_PATH:-$SCRIPT_DIR/models/Qwen3-30B-A3B-Q4_K_M.gguf}"
# HF fallback: set MODEL_HF to download/load via llama-server -hf
# Primary: bartowski/Qwen3-30B-A3B-GGUF:Q4_K_M
# Fallback: unsloth/Qwen3-30B-A3B-GGUF:Q4_K_M
MODEL_HF="${MODEL_HF:-}"

if [ -n "$MODEL_HF" ]; then
    MODEL_ARG=(-hf "$MODEL_HF")
    MODEL_DISPLAY="$MODEL_HF (hf)"
else
    if [ ! -f "$MODEL_PATH" ]; then
        echo "Error: model not found at: $MODEL_PATH"
        echo ""
        echo "Either:"
        echo "  1. Place the GGUF at $MODEL_PATH"
        echo "  2. Run: sbatch models.sbatch <repo:quant>  (downloads to cache)"
        echo "  3. Override: MODEL_HF=<repo:quant> sbatch server-speedrun-rtx3070.sbatch"
        exit 1
    fi
    MODEL_ARG=(-m "$MODEL_PATH")
    MODEL_DISPLAY="$MODEL_PATH (local)"
fi

# ── Runtime config — Test B defaults ──
PORT="${PORT:-8080}"
CTX="${CTX:-32768}"
N_CPU_MOE="${N_CPU_MOE:-34}"
CTK="${CTK:-q8_0}"
CTV="${CTV:-q8_0}"
THREADS="${THREADS:-16}"

# ── Validate port ──
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65535 ]; then
    echo "Error: PORT must be between 1024 and 65535 (got: '$PORT')"
    exit 1
fi

# ── GPU node validation ──
echo "Checking GPU..."
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1)
echo "  GPU: $GPU_NAME"
if ! echo "$GPU_NAME" | grep -qi "3070"; then
    echo "ERROR: This speedrun script expects an RTX 3070. Got: $GPU_NAME"
    echo "       Check your SLURM exclude list or re-submit."
    exit 1
fi
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
echo ""

# ── Flag validation ──
echo "Checking llama-server supports required flags..."
if ! "$LLAMA_BIN_DIR/llama-server" --help 2>&1 | grep -q "n-cpu-moe"; then
    echo "ERROR: --n-cpu-moe flag not found in this llama-server build."
    echo "       This flag requires a recent llama.cpp build with MoE support."
    echo "       Re-run: sbatch build.sbatch"
    exit 1
fi
echo "  ✓ --n-cpu-moe supported"
echo ""

NODE=$(hostname)

echo "=========================================="
echo "llama.cpp RTX3070 Speedrun Server"
echo "=========================================="
echo "Node:        $NODE"
echo "GPU:         $GPU_NAME"
echo "Model:       $MODEL_DISPLAY"
echo "Port:        $PORT"
echo "Context:     $CTX"
echo "n-cpu-moe:   $N_CPU_MOE"
echo "KV cache:    ctk=$CTK  ctv=$CTV"
echo "Threads:     $THREADS"
echo ""
echo "Build info:"
if [ -f "$SCRIPT_DIR/llama-build-info.env" ]; then
    cat "$SCRIPT_DIR/llama-build-info.env"
else
    echo "  (llama-build-info.env not found — rebuild with current build.sbatch)"
fi
echo ""
echo "Connect:"
echo "  ssh -L $PORT:localhost:$PORT $(whoami)@$NODE"
echo "  http://localhost:$PORT/v1/chat/completions"
echo ""
echo "Monitor (run in another terminal on this node):"
echo "  watch -n 1 nvidia-smi"
echo "  watch -n 1 free -h"
echo "  PID=\$(pgrep -f llama-server | head -n1); grep -E 'VmLck|VmRSS|VmSize' /proc/\$PID/status"
echo "=========================================="
echo ""

exec "$LLAMA_BIN_DIR/llama-server" \
    "${MODEL_ARG[@]}" \
    --host 0.0.0.0 \
    --port "$PORT" \
    -ngl 99 \
    --n-cpu-moe "$N_CPU_MOE" \
    --no-mmap \
    --flash-attn on \
    -c "$CTX" \
    -ctk "$CTK" \
    -ctv "$CTV" \
    -t "$THREADS"
