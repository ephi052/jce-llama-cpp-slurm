# TurboQuant Track

**Attempt this ONLY after Track A (upstream llama.cpp) runs stably.**

## What it is

TurboQuant is a llama.cpp fork that adds sub-4-bit KV cache quantization types:
- `tq4_0` — 4-bit turbo KV cache
- `tq3_0` — 3-bit turbo KV cache

These allow significantly larger context windows within the same VRAM budget.

## How to build

Override `LLAMA_CPP_REPO` at submit time:

```bash
LLAMA_CPP_REPO=https://github.com/TheTom/llama-cpp-turboquant.git \
LLAMA_CPP_REF=<pinned-commit> \
CUDA_ARCHS=86 \
sbatch build.sbatch
```

The build output will be in the same `llama.cpp/` directory. **Back up your
working upstream build first** if you want to switch back easily.

## How to pin a commit

Before running, record the exact commit you are testing:

```bash
cd llama.cpp
git log --oneline -n 5
git rev-parse HEAD
```

The SHA will be written automatically to `llama-build-info.env` by `build.sbatch`.

## Test matrix

| Test | ctk   | ctv   | ctx    | Goal           |
| ---- | ----- | ----- | -----: | -------------- |
| F    | q8_0  | q4_0  | 131072 | stretch ctx    |
| G    | tq4_0 | tq3_0 | 131072 | full TurboQuant|

```bash
# Test F — long context with standard quants
N_CPU_MOE=36 CTX=131072 CTK=q8_0 CTV=q4_0 sbatch server-speedrun-rtx3070.sbatch

# Test G — TurboQuant KV cache (requires TurboQuant build)
N_CPU_MOE=36 CTX=131072 CTK=tq4_0 CTV=tq3_0 sbatch server-speedrun-rtx3070.sbatch
```

## Flag validation

The speedrun server script already checks that `--n-cpu-moe` is present.
Before Test G, also confirm the TurboQuant types are available:

```bash
./llama.cpp/build/bin/llama-server --help | grep -E "tq4|tq3"
```

If that returns nothing, the TurboQuant build did not succeed or is not the active build.
