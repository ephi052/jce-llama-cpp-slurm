# JCE llama.cpp on SLURM

Student guide for building, serving, and using local LLMs on the JCE HPC cluster with [llama.cpp](https://github.com/ggerganov/llama.cpp) and CUDA GPUs.

Run local LLM inference on the JCE HPC cluster using an OpenAI-compatible API, so you can connect with `curl`, Python, or any OpenAI SDK.

> **JCE students:** this guide uses the `rtx2080` and `rtx3070` partitions and standard JCE module paths. If you are using a different cluster, adjust the partition name and CUDA path accordingly.

## Prerequisites

- Access to the JCE HPC cluster (SLURM)
- CUDA 12.x on compute nodes (pre-installed at `/usr/local/cuda`)
- One-time conda setup (see [docs/conda.md](docs/conda.md))
- Hugging Face account (for downloading gated models)

## Quick Start

```bash
# 1. One-time: create the cmake conda environment
module load anaconda
conda create -n llama-build cmake -y

# 2. Clone this repo
git clone <this-repo-url>
cd <repo-name>

# 3. Build llama.cpp with CUDA (runs on a GPU node via SLURM)
sbatch build.sbatch

# 4. Download a model
sbatch models.sbatch Qwen/Qwen2.5-7B-Instruct-GGUF:Q4_K_M

# 5. Start the API server
sbatch server.sbatch

# 6. Connect from your laptop (SSH tunnel)
ssh -L 8080:localhost:8080 <username>@<compute-node>
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello!"}]}'
```

## Files

| File | Purpose |
|------|---------|
| `build.sbatch` | Clone and build llama.cpp with CMake + CUDA. Generates `env.sh`. |
| `models.sbatch` | Pre-download a model from Hugging Face. Updates `env.sh`. |
| `server.sbatch` | Start an OpenAI-compatible API server on a GPU node. |
| `env.sh` | Generated config — paths, model name, defaults. Not committed. |

## Usage

### Build

```bash
sbatch build.sbatch
```

The build runs on an `rtx2080` node by default. To use a different partition:

```bash
sbatch -p rtx3070 build.sbatch
```

The binary is a multi-arch CUDA fat binary (supports `sm_75` RTX 2080 and `sm_86` RTX 3070 by default).

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

### Start the server

```bash
# Default (uses HF_MODEL and port 8080 from env.sh)
sbatch server.sbatch

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
# Tunnel port 8080 from the compute node to your laptop
ssh -L 8080:localhost:8080 <username>@<compute-node>

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

The total context (`--ctx-size`) is split evenly across `--parallel` slots.
**Each request uses one slot**, so:

| `ctx-size` | `parallel` | Tokens per request | Notes |
|-----------|------------|--------------------|-------|
| 4096 | 1 | **4096** | default — best for single-user |
| 4096 | 4 | 1024 | 4 concurrent users, short context |
| 8192 | 1 | **8192** | longer documents/code |
| 16384 | 1 | **16384** | max practical on 8GB GPU |

See [docs/context-config.md](docs/context-config.md) for the full reference.

## JCE Cluster — GPU Partitions

| Partition | GPU | VRAM | Good for |
|-----------|-----|------|----------|
| `rtx2080` | RTX 2080 SUPER | 8 GB | 7B models, Q4 quants |
| `rtx3070` | RTX 3070 | 8 GB | same as above, newer arch |
| `rtx1080` | GTX 1080 | 8 GB | smaller models only |

Submit to a specific partition:

```bash
sbatch -p rtx3070 server.sbatch
```

> **Important:** the build binary must include the target GPU's CUDA architecture (`sm_86` for RTX 3070, `sm_75` for RTX 2080). The default `build.sbatch` includes both.

## Troubleshooting

### `CUDA error: no kernel image is available for execution on the device`
The binary was built for a different GPU architecture. Rebuild:
```bash
sbatch build.sbatch   # already includes sm_75 and sm_86 by default
```

### `error: Batch job submission failed: Requested node configuration is not available`
The partition name is wrong, or you requested a `--gres` type that doesn't match the partition. Try `-p main --gres=gpu:rtx_3070:1` or just `-p rtx3070`.

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
