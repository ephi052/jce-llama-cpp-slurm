# JCE llama.cpp on SLURM

Student guide for building, serving, and using local LLMs on the JCE HPC cluster with [llama.cpp](https://github.com/ggerganov/llama.cpp) and CUDA GPUs.

Run local LLM inference on the JCE HPC cluster using an OpenAI-compatible API, so you can connect with `curl`, Python, or any OpenAI SDK.

> **30B-class local LLMs on an 8GB GPU.** This repo packages a tested JCE workflow for running Qwen3-30B-A3B and Qwen3.6-35B-A3B on a single RTX3070 8GB, including a published 131k-context Qwen3.6 speedrun that reached 38.72 tok/s in the safe default configuration.

> **JCE students:** the current scripts target the `main` partition and exclude 1080 Ti / 2080 nodes so jobs land on RTX3070-class hardware. If you are using a different cluster, adjust the partition and exclude list accordingly.

## Prerequisites

- Access to the JCE HPC cluster (SLURM)
- CUDA 12.x on compute nodes (pre-installed at `/usr/local/cuda`)
- One-time conda setup (see [docs/conda.md](docs/conda.md))
- Hugging Face account for model browsing; token only needed for gated models
- Optional: `huggingface-cli` or `curl` for manual local GGUF downloads

## Quick Start

```bash
# 1. One-time: create the cmake conda environment
module load anaconda
conda create -n llama-build cmake -y

# 2. Clone this repo
git clone <this-repo-url>
cd <repo-name>

# 3. Build the tested TurboQuant fork (RTX3070 / Qwen3.6 track)
LLAMA_CPP_REPO=https://github.com/TheTom/llama-cpp-turboquant.git \
LLAMA_CPP_REF=5aeb2fdbe26cd4c534c6fa15de73cb5749bd0403 \
CUDA_ARCHS=86 \
sbatch build.sbatch

# 4. Download the tested Qwen3.6 GGUF locally
mkdir -p models
curl -L -o models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf \
  "https://huggingface.co/bartowski/Qwen_Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf"

# 5. Start the tested RTX3070 speedrun config
MODEL_PATH=./models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf \
  N_CPU_MOE=34 CTX=131072 \
  sbatch server-speedrun-rtx3070.sbatch

# 6. Connect from your laptop (SSH tunnel via login node)
ssh -L 8080:<compute-node>:8080 <username>@hpc-master
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello!"}]}'
```

## Published Results

- Qwen3.6 RTX3070 speedrun: [results/rtx3070-qwen36-35b-a3b-speedrun.md](results/rtx3070-qwen36-35b-a3b-speedrun.md)
- Qwen3-30B-A3B baseline/turboquant track: [results/rtx3070-qwen3-30b-a3b-speedrun.md](results/rtx3070-qwen3-30b-a3b-speedrun.md)

Current recommended default on RTX3070 8 GB:

```bash
MODEL_PATH=./models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf \
  N_CPU_MOE=34 CTX=131072 \
  sbatch server-speedrun-rtx3070.sbatch
```

Fastest tested but riskier VRAM profile:

```bash
MODEL_PATH=./models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf \
  N_CPU_MOE=32 CTX=131072 \
  sbatch server-speedrun-rtx3070.sbatch
```

## Files

| File | Purpose |
|------|---------|
| `build.sbatch` | Clone and build llama.cpp with CMake + CUDA. Generates `env.sh`. |
| `models.sbatch` | Pre-download a model from Hugging Face. Updates `env.sh`. |
| `server.sbatch` | Start an OpenAI-compatible API server on a GPU node. |
| `server-speedrun-rtx3070.sbatch` | Start the tested RTX3070 speedrun server for Qwen3/Qwen3.6 benchmarking. |
| `results/*.md` | Benchmarked configurations and recommended defaults. |
| `env.sh` | Generated config — paths, model name, defaults. Not committed. |

## Usage

### Build

```bash
sbatch build.sbatch
```

The build runs on the `main` partition and excludes 1080 Ti / 2080 nodes so the tested CUDA 8.6 build lands on RTX3070-class hardware. To override the CUDA arch explicitly:

```bash
CUDA_ARCHS=86 sbatch build.sbatch
```

For the published Qwen3.6 track, use the tested TurboQuant pin:

```bash
LLAMA_CPP_REPO=https://github.com/TheTom/llama-cpp-turboquant.git \
LLAMA_CPP_REF=5aeb2fdbe26cd4c534c6fa15de73cb5749bd0403 \
CUDA_ARCHS=86 \
sbatch build.sbatch
```

To pin to a specific llama.cpp version instead of latest:

```bash
LLAMA_CPP_REF=b5261 sbatch build.sbatch
```

### Download a model

Uses the `-hf <repo>:<quant>` format. Browse GGUFs at [huggingface.co](https://huggingface.co/models?search=gguf).

```bash
sbatch models.sbatch Qwen/Qwen2.5-7B-Instruct-GGUF:Q4_K_M
sbatch models.sbatch TheBloke/deepseek-coder-6.7B-instruct-GGUF:Q4_K_M
sbatch models.sbatch bartowski/Meta-Llama-3.1-8B-Instruct-GGUF:Q4_K_M
```

The model is cached in `./models/` and set as default in `env.sh`.

For the tested Qwen3.6 speedrun, the simpler path is to download the GGUF directly into `./models/` and pass `MODEL_PATH`:

```bash
mkdir -p models

# Option A: huggingface-cli
huggingface-cli download \
  bartowski/Qwen_Qwen3.6-35B-A3B-GGUF \
  Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf \
  --local-dir ./models

# Option B: curl
curl -L -o models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf \
  "https://huggingface.co/bartowski/Qwen_Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf"
```

Then launch it with:

```bash
MODEL_PATH=./models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf \
  N_CPU_MOE=34 CTX=131072 \
  sbatch server-speedrun-rtx3070.sbatch
```

### Start the server

```bash
# Default (uses HF_MODEL and port 8080 from env.sh)
sbatch server.sbatch

# Tested RTX3070 Qwen3.6 default
MODEL_PATH=./models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf \
  N_CPU_MOE=34 CTX=131072 \
  sbatch server-speedrun-rtx3070.sbatch

# Specific model
sbatch server.sbatch TheBloke/deepseek-coder-6.7B-instruct-GGUF:Q4_K_M

# Specific model + port
sbatch server.sbatch TheBloke/deepseek-coder-6.7B-instruct-GGUF:Q4_K_M 9090

# Specific model + port + parallel slots
sbatch server.sbatch TheBloke/deepseek-coder-6.7B-instruct-GGUF:Q4_K_M 8080 4

# Different partition (e.g. RTX 3070 nodes)
sbatch -p rtx3070 server.sbatch TheBloke/deepseek-coder-6.7B-instruct-GGUF:Q4_K_M 8082 1
```

Check which node was assigned:

```bash
grep "Node:" llama_server_*.log
# or
squeue -u $USER
```

### Connect to the server

See [docs/ssh-tunnel.md](docs/ssh-tunnel.md) for full instructions.

```bash
# Tunnel port 8080 from the compute node to your laptop via the login node
ssh -L 8080:<compute-node>:8080 <username>@hpc-master

# Then test
curl http://localhost:8080/health
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello!"}]}'
```

### Stop the server

```bash
scancel <job_id>
```

## Context size vs. parallelism

This section applies to the generic `server.sbatch` path.

The total context (`--ctx-size`) is split evenly across `--parallel` slots.
**Each request uses one slot**, so:

| `ctx-size` | `parallel` | Tokens per request | Notes |
|-----------|------------|--------------------|-------|
| 4096 | 1 | **4096** | default — best for single-user |
| 4096 | 4 | 1024 | 4 concurrent users, short context |
| 8192 | 1 | **8192** | longer documents/code |
| 16384 | 1 | **16384** | conservative generic 8GB setting |

See [docs/context-config.md](docs/context-config.md) for the full reference.

For the RTX3070 speedrun path, the tested Qwen3.6 configuration is very different: the hybrid Mamba+attention architecture was stable at `CTX=131072` with `N_CPU_MOE=34`, and even faster at `N_CPU_MOE=32` with higher VRAM risk. Use the speedrun results docs for those model-specific limits rather than treating the table above as a hard 8GB limit.

## JCE Cluster — GPU Partitions

| Partition | GPU | VRAM | Good for |
|-----------|-----|------|----------|
| `rtx2080` | RTX 2080 SUPER | 8 GB | smaller generic llama.cpp runs |
| `rtx3070` | RTX 3070 | 8 GB | tested Qwen3-30B-A3B and Qwen3.6-35B-A3B speedruns |
| `rtx1080` | GTX 1080 | 8 GB | smaller models only |

Submit to a specific partition:

```bash
sbatch -p rtx3070 server.sbatch
```

> **Important:** the current published speedrun flow builds for `sm_86` RTX 3070 by default. If you need RTX 2080 compatibility too, override `CUDA_ARCHS=75;86` when submitting `build.sbatch`.

## Troubleshooting

### `CUDA error: no kernel image is available for execution on the device`
The binary was built for a different GPU architecture. Rebuild:
```bash
CUDA_ARCHS=86 sbatch build.sbatch
```

### `error: Batch job submission failed: Requested node configuration is not available`
The partition name or exclude list is wrong for your cluster. For this repo's current JCE setup, use the bundled `main`-partition sbatch files as-is, or adapt the `#SBATCH --partition` / `#SBATCH --exclude` lines for your site.

### Model download stuck / hanging
The download job polls for snapshot files every 5 seconds. If it times out, submit again — partial downloads resume from the HF cache automatically.

### `context length exceeded` errors
Reduce `--parallel` or increase `--ctx-size`. See [docs/context-config.md](docs/context-config.md).

### Gated model (403 Forbidden)
Some models require accepting a license on Hugging Face. Visit `huggingface.co/<repo>`, accept the license, then pass your token:
```bash
export HF_TOKEN=hf_...
sbatch models.sbatch meta-llama/Meta-Llama-3.1-8B-Instruct-GGUF:Q4_K_M
```

### `cmake not found` after activating conda env
```bash
module load anaconda
conda create -n llama-build cmake -y   # see docs/conda.md
```

## Project Layout

```
.                         # ← committed (this repo)
├── build.sbatch          # build llama.cpp with CUDA
├── models.sbatch         # download a model from HF
├── server.sbatch         # start the API server
├── README.md
├── LICENSE
├── .gitignore
└── docs/
    ├── conda.md          # one-time conda setup
    ├── ssh-tunnel.md     # connect from your laptop
    └── context-config.md # ctx-size / parallel tuning

                          # ← generated at runtime (git-ignored)
├── env.sh                # created by build.sbatch
├── llama.cpp/            # cloned + built by build.sbatch
├── models/               # downloaded by models.sbatch
└── *.log                 # SLURM job logs
```

## License

MIT — see [LICENSE](LICENSE).
