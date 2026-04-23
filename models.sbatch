#!/bin/bash
#SBATCH --job-name=llama_model
#SBATCH --output=model_%j.log
#SBATCH --error=model_%j.log
#SBATCH --partition=rtx2080
#SBATCH --gres=gpu:1
#SBATCH --time=01:00:00

# Default partition is rtx2080.
# Override at submit time, e.g.:
#   sbatch -p <partition> models.sbatch <repo:quant>

# Pre-download a model and set it as the default.
# Uses the same -hf syntax as llama-cli / llama-server.
#
# Usage: sbatch models.sbatch <repo:quant>
# Examples:
#   sbatch models.sbatch Qwen/Qwen2.5-7B-Instruct-GGUF:Q4_K_M
#   sbatch models.sbatch Qwen/Qwen2.5-7B-Instruct-GGUF:Q4_0
#   sbatch models.sbatch bartowski/Meta-Llama-3.1-8B-Instruct-GGUF:Q4_K_M
#   sbatch models.sbatch TheBloke/Mistral-7B-Instruct-v0.2-GGUF:Q4_K_M

set -e

SCRIPT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
cd "$SCRIPT_DIR"
source env.sh

MODEL="$1"
MODEL_REPO="${MODEL%%:*}"
CACHE_REPO_DIR="$LLAMA_CACHE/models--${MODEL_REPO//\//--}"
SNAPSHOT_GLOB="$CACHE_REPO_DIR/snapshots/*/*.gguf"

# ── Validate ──
if [ -z "$MODEL" ]; then
    echo "Error: please provide a model in HuggingFace format."
    echo ""
    echo "Usage: sbatch models.sbatch <repo:quant>"
    echo ""
    echo "Examples:"
    echo "  sbatch models.sbatch Qwen/Qwen2.5-7B-Instruct-GGUF:Q4_K_M"
    echo "  sbatch models.sbatch bartowski/Meta-Llama-3.1-8B-Instruct-GGUF:Q4_K_M"
    echo ""
    echo "Browse models at: https://huggingface.co/models?search=gguf"
    exit 1
fi

echo "=========================================="
echo "Downloading Model via llama-cli -hf"
echo "=========================================="
echo "Date:  $(date)"
echo "Model: $MODEL"
echo "Cache: $LLAMA_CACHE"
echo ""

mkdir -p "$LLAMA_CACHE"

if [ -d "$CACHE_REPO_DIR/blobs" ] && find "$CACHE_REPO_DIR/blobs" -type f | grep -q .; then
    echo "Model cache already exists for $MODEL_REPO"
    echo "Skipping download step."
    echo ""
else

    # ── Download ──
    # -hf auto-downloads and caches the model.
    # Run llama-cli in the background and stop it as soon as the completed
    # snapshot .gguf files appear in the HF cache, which avoids waiting for a
    # full model load/inference after download.
    echo "Downloading (this may take several minutes)..."
    echo ""

    set +e
    $LLAMA_BIN_DIR/llama-cli \
        -hf "$MODEL" \
        -ngl 0 \
        --no-warmup \
        -n 1 \
        -p "hi" \
        > /dev/null 2>&1 &

    DOWNLOAD_PID=$!
    set -e

    DOWNLOAD_DONE=0
    for _ in $(seq 1 180); do
        if compgen -G "$SNAPSHOT_GLOB" > /dev/null; then
            echo "  ✓ Cache files downloaded"
            DOWNLOAD_DONE=1
            kill "$DOWNLOAD_PID" 2>/dev/null || true
            wait "$DOWNLOAD_PID" 2>/dev/null || true
            break
        fi

        if ! kill -0 "$DOWNLOAD_PID" 2>/dev/null; then
            wait "$DOWNLOAD_PID"
            DOWNLOAD_STATUS=$?
            if [ $DOWNLOAD_STATUS -ne 0 ]; then
                echo "  ✗ Download/load failed (exit code: $DOWNLOAD_STATUS)"
                exit 1
            fi
            if compgen -G "$SNAPSHOT_GLOB" > /dev/null; then
                echo "  ✓ Cache files downloaded"
                DOWNLOAD_DONE=1
                break
            fi
            echo "  ✗ Download finished but no cached .gguf files were found"
            exit 1
        fi

        sleep 5
    done

    if [ $DOWNLOAD_DONE -ne 1 ]; then
        echo "  ✗ Timed out waiting for cached .gguf files"
        kill "$DOWNLOAD_PID" 2>/dev/null || true
        wait "$DOWNLOAD_PID" 2>/dev/null || true
        exit 1
    fi

    echo ""
    echo "  ✓ Download complete!"
    echo ""
fi

# ── Set as default ──
echo "Setting as default model in env.sh..."
sed -i "s|^export HF_MODEL=.*|export HF_MODEL=\"$MODEL\"|" "$SCRIPT_DIR/env.sh"
echo "  ✓ HF_MODEL=$MODEL"
echo ""

# ── Show cached models ──
echo "Cached models in $LLAMA_CACHE:"
find "$LLAMA_CACHE" -name "*.gguf" -exec ls -lh {} \; 2>/dev/null || echo "  (none found)"
echo ""

echo "=========================================="
echo "✓ Model Ready!"
echo "=========================================="
echo ""
echo "Start the server:"
echo "  sbatch server.sbatch"
echo ""
echo "Or serve this model directly:"
echo "  sbatch server.sbatch \"$MODEL\""
echo ""
