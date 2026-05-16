# RTX3070 Qwen3.6-35B-A3B Speedrun Results

Model: Qwen3.6-35B-A3B Q4_K_M  
GGUF: `Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf`  
Build: see `llama-build-info.env`

## Winner

```bash
MODEL_PATH=./models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf \
  N_CPU_MOE=34 CTX=131072 \
  sbatch server-speedrun-rtx3070.sbatch
```

Result:

- tok/s: 38.72
- VRAM: 6874/8192 MiB, 84%
- Context: 131072
- Status: recommended default

## Test Matrix

|   Job | `--n-cpu-moe` |    ctx | tok/s |           VRAM | Result                |
| ----: | ------------: | -----: | ----: | -------------: | --------------------- |
| 29890 |            42 |  32768 | 32.04 | 3228/8192, 39% | too conservative      |
| 29891 |            34 |  32768 | 35.90 | 5831/8192, 71% | good                  |
| 29892 |            42 | 131072 | 32.71 | 4247/8192, 52% | safe but conservative |
| 29893 |            30 |  32768 | 39.59 | 7623/8192, 93% | fastest but too close |
| 29896 |            34 | 131072 | 38.72 | 6874/8192, 84% | winner (safe default) |
| 29897 |            32 | 131072 | 40.82 | 7738/8192, 94% | fastest but risky     |

## Findings

- `N_CPU_MOE=42` is too conservative: VRAM is low, but speed is lower.
- `N_CPU_MOE=34` gives the best practical balance.
- `N_CPU_MOE=30` is fastest at 32k, but 93% VRAM is too close for a default.
- `CTX=131072` costs surprisingly little extra VRAM on this Qwen3.6 build.
- The best default is `N_CPU_MOE=34 CTX=131072`.
- `N_CPU_MOE=32 CTX=131072` gives 40.82 tok/s (fastest) but at 94% VRAM — risky for large prompt fills.

## Recommended Commands

### Default long-context worker

```bash
MODEL_PATH=./models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf \
  N_CPU_MOE=34 CTX=131072 \
  sbatch server-speedrun-rtx3070.sbatch
```

### Fast but risky (demo mode)

```bash
MODEL_PATH=./models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf \
  N_CPU_MOE=32 CTX=131072 \
  sbatch server-speedrun-rtx3070.sbatch
```

## Next Tests

| Test | Command idea                                           | Goal                                                |
| ---- | ------------------------------------------------------ | --------------------------------------------------- |
| H    | `N_CPU_MOE=32 CTX=131072 CTK=turbo4 CTV=turbo3`        | try to keep the fastest 131k config with safer VRAM |
| I    | `N_CPU_MOE=30 CTX=131072 CTK=turbo4 CTV=turbo3`        | see if TurboQuant makes the faster 30-MoE run viable |
| J    | `N_CPU_MOE=34 CTX=262144 CTK=turbo4 CTV=turbo3`        | stretch context with the current safe default       |
| K    | `N_CPU_MOE=36 CTX=262144 CTK=turbo4 CTV=turbo3`        | safer 262k stretch test with extra CPU offload      |

## Notes

Qwen3.6 behaves very differently from Qwen3-30B-A3B. The older Qwen3-30B-A3B sweet spot was around `N_CPU_MOE=38`, but Qwen3.6 can push more experts onto GPU safely at `N_CPU_MOE=34`. The hybrid Mamba+attention architecture (`full_attention_interval=4`) means KV cache is ~4x cheaper than a pure transformer, making large context cheap on VRAM.
