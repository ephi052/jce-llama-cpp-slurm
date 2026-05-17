# RTX3070 Qwen3.6-35B-A3B Speedrun Results

Model: Qwen3.6-35B-A3B Q4_K_M  
GGUF: `Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf`  
Build: see `llama-build-info.env`

## Winner

```bash
MODEL_PATH=./models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf \
  N_CPU_MOE=34 CTX=262144 CTK=turbo4 CTV=turbo3 \
  sbatch server-speedrun-rtx3070.sbatch
```

Result:

- tok/s: 36.80
- VRAM: 7177/8192 MiB, 88%
- Context: 262144
- Status: recommended long-context default

## Test Matrix

|   Job | `--n-cpu-moe` |    ctx | tok/s |           VRAM | Result                |
| ----: | ------------: | -----: | ----: | -------------: | --------------------- |
| 29890 |            42 |  32768 | 32.04 | 3228/8192, 39% | too conservative      |
| 29891 |            34 |  32768 | 35.90 | 5831/8192, 71% | good                  |
| 29892 |            42 | 131072 | 32.71 | 4247/8192, 52% | safe but conservative |
| 29893 |            30 |  32768 | 39.59 | 7623/8192, 93% | fastest but too close |
| 29896 |            34 | 131072 | 38.72 | 6874/8192, 84% | best q8/q8 131k default |
| 29897 |            32 | 131072 | 40.82 | 7738/8192, 94% | fastest but risky     |
| 29898 |            32 | 131072 | 31.10 | 6970/8192, 85% | TurboQuant saved VRAM, but slowed a lot |
| 29899 |            30 | 131072 | 38.69 | 7898/8192, 96% | TurboQuant made 30-MoE viable, but too close |
| 29900 |            34 | 262144 | 36.80 | 7177/8192, 88% | winner (262k default) |
| 29901 |            36 | 262144 | 35.18 | 6181/8192, 75% | safer 262k variant — validated: 194k real browser chat, 8.8 t/s sustained, 6585/8192 MiB (80%) at peak |

## Findings

- `N_CPU_MOE=42` is too conservative: VRAM is low, but speed is lower.
- `N_CPU_MOE=34` gives the best practical balance and remains the best base for the long-context default.
- `N_CPU_MOE=30` is fastest at 32k, but 93% VRAM is too close for a default.
- `CTX=131072` costs surprisingly little extra VRAM on this Qwen3.6 build.
- TurboQuant on Qwen3.6 helps differently than on Qwen3-30B-A3B: it is more useful for pushing context higher than for improving 131k speed.
- `N_CPU_MOE=32 CTX=131072` gives 40.82 tok/s (fastest) but at 94% VRAM — risky for large prompt fills.
- `N_CPU_MOE=32 CTX=131072 CTK=turbo4 CTV=turbo3` reduced VRAM by about 0.75 GiB, but speed fell sharply to 31.10 tok/s.
- `N_CPU_MOE=30 CTX=131072 CTK=turbo4 CTV=turbo3` ran at 38.69 tok/s, showing TurboQuant can make the 30-MoE 131k run possible, but 96% VRAM is still too close for a default.
- The biggest TurboQuant win is `N_CPU_MOE=34 CTX=262144 CTK=turbo4 CTV=turbo3`: 262k context at 36.80 tok/s and 88% VRAM.
- The best default is now `N_CPU_MOE=34 CTX=262144 CTK=turbo4 CTV=turbo3`.
- Real-world validation: `N_CPU_MOE=36 CTX=262144 CTK=turbo4 CTV=turbo3` (job 29901) successfully handled a 193k-token browser conversation at sustained 9.2 t/s, confirming the 262k window is usable under real load.

## Recommended Commands

### Default long-context worker

```bash
MODEL_PATH=./models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf \
  N_CPU_MOE=34 CTX=262144 CTK=turbo4 CTV=turbo3 \
  sbatch server-speedrun-rtx3070.sbatch
```

### Fast but risky (demo mode)

```bash
MODEL_PATH=./models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf \
  N_CPU_MOE=32 CTX=131072 \
  sbatch server-speedrun-rtx3070.sbatch
```

### Safer 262k variant

```bash
MODEL_PATH=./models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf \
  N_CPU_MOE=36 CTX=262144 CTK=turbo4 CTV=turbo3 \
  sbatch server-speedrun-rtx3070.sbatch
```

## Next Tests

| Test | Command idea                                           | Goal                                                |
| ---- | ------------------------------------------------------ | --------------------------------------------------- |
| L    | `N_CPU_MOE=32 CTX=262144 CTK=turbo4 CTV=turbo3`        | aggressive 262k stretch; may be near VRAM edge      |
| M    | `N_CPU_MOE=34 CTX=262144 CTK=turbo3 CTV=turbo2`        | test whether stronger KV compression helps prompt-fill safety |
| N    | `N_CPU_MOE=36 CTX=262144 CTK=turbo3 CTV=turbo2`        | safer 262k variant with extra KV headroom           |
| O    | `N_CPU_MOE=34 CTX=131072 CTK=turbo3 CTV=turbo2`        | isolate the effect of stronger KV compression at a stable 131k setting |

## Notes

Qwen3.6 behaves very differently from Qwen3-30B-A3B. The older Qwen3-30B-A3B sweet spot was around `N_CPU_MOE=38`, but Qwen3.6 can push more experts onto GPU safely at `N_CPU_MOE=34`. The hybrid Mamba+attention architecture (`full_attention_interval=4`) means KV cache is ~4x cheaper than a pure transformer, making large context cheap on VRAM. On Qwen3.6, TurboQuant's biggest value is enabling a strong 262k-context default, not improving the fastest 131k benchmark.
