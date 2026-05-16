# TurboQuant Track

**Attempt this ONLY after Track A (upstream llama.cpp) runs stably.**

## What it is

TurboQuant is a llama.cpp fork that adds sub-4-bit KV cache quantization types:
- `turbo4` — 4-bit turbo KV cache
- `turbo3` — 3-bit turbo KV cache
- `turbo2` — 2-bit turbo KV cache

These allow significantly larger context windows within the same VRAM budget.

If you omit `CTX`, `CTK`, or `CTV` when launching `server-speedrun-rtx3070.sbatch`, the script falls back to its defaults:
- `CTX=32768`
- `CTK=q8_0`
- `CTV=q8_0`

That means TurboQuant is **not** enabled automatically. To use TurboQuant KV compression, you must explicitly pass `CTK=` and `CTV=` with `turbo4`, `turbo3`, or `turbo2`.

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
| F    | turbo4 | turbo3 | 65536  | TurboQuant 65k |
| G    | turbo4 | turbo3 | 131072 | 131k stretch   |

```bash
# Test F — TurboQuant 65k (best long-context config tested)
N_CPU_MOE=38 CTX=65536 CTK=turbo4 CTV=turbo3 sbatch server-speedrun-rtx3070.sbatch

# Test G — TurboQuant 131k stretch (requires TurboQuant build)
N_CPU_MOE=38 CTX=131072 CTK=turbo4 CTV=turbo3 sbatch server-speedrun-rtx3070.sbatch
```

## Can TurboQuant compress more?

Yes, in principle. `turbo3` and `turbo2` are more aggressive KV-cache compression modes than `turbo4`.

For example:

```bash
# More aggressive, not part of the published tested baseline
N_CPU_MOE=38 CTX=131072 CTK=turbo3 CTV=turbo2 sbatch server-speedrun-rtx3070.sbatch
```

But that is a new experiment, not a documented result yet. The published track only validated:
- `CTK=turbo4 CTV=turbo3` at 65k as the best long-context config
- `CTK=turbo4 CTV=turbo3` at 131k as a stretch/demo config with OOM risk on large prompt fill

## Next tests to push further

These are the next practical experiments if you want to push beyond the published baseline without changing the speedrun script itself.

| Test | Command idea | Goal |
| ---- | ------------ | ---- |
| H | `N_CPU_MOE=38 CTX=131072 CTK=turbo3 CTV=turbo2` | reduce KV-cache footprint vs. Test G |
| I | `N_CPU_MOE=40 CTX=131072 CTK=turbo4 CTV=turbo3` | trade some speed for more VRAM headroom |
| J | `N_CPU_MOE=40 CTX=131072 CTK=turbo3 CTV=turbo2` | combine extra CPU offload with more aggressive KV compression |

```bash
# Test H — more aggressive KV compression at the same 131k context
N_CPU_MOE=38 CTX=131072 CTK=turbo3 CTV=turbo2 sbatch server-speedrun-rtx3070.sbatch

# Test I — same TurboQuant profile as Test G, but offload more MoE work to CPU
N_CPU_MOE=40 CTX=131072 CTK=turbo4 CTV=turbo3 sbatch server-speedrun-rtx3070.sbatch

# Test J — combine more CPU offload with more aggressive KV compression
N_CPU_MOE=40 CTX=131072 CTK=turbo3 CTV=turbo2 sbatch server-speedrun-rtx3070.sbatch
```

### Notes on interpreting them

- If Test H succeeds on large prompt fill, the bottleneck was primarily KV-cache pressure.
- If Test I succeeds but Test H does not, the bottleneck was more about model/KV balance than KV type alone.
- If only Test J is stable, 131k is possible but requires both more aggressive KV compression and extra CPU offload.
- Disabling prompt cache with `--cache-ram 0` is another useful follow-up, but the current `server-speedrun-rtx3070.sbatch` does not expose that flag yet.

## Flag validation

The speedrun server script already checks that `--n-cpu-moe` is present.
Before Test G, also confirm the TurboQuant types are available:

```bash
./llama.cpp/build/bin/llama-server --help | grep -E "turbo2|turbo3|turbo4"
```

If that returns nothing, the TurboQuant build did not succeed or is not the active build.
