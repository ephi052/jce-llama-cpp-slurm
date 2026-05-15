# RTX3070 Qwen3-30B-A3B Speedrun Results

Model: Qwen3-30B-A3B Q4_K_M  
Build: see `llama-build-info.env`

## Test Matrix

| Test | `--n-cpu-moe` | ctx   | ctk  | ctv  | Goal                      | tok/s | VRAM       | RAM   | Stable |
| ---- | ------------: | ----: | ---- | ---- | ------------------------- | ----: | ---------: | ----: | ------ |
| A    |            38 | 16384 | q8_0 | q8_0 | baseline, fastest so far  | 33.44 | 5772/8192  | 14/30 | ✓      |
| B    |            34 | 32768 | q8_0 | q8_0 | too close to VRAM max     | 30.22 | 7928/8192  | 13/30 | ✓      |
| C    |            38 | 32768 | q8_0 | q8_0 | isolate context effect    | 31.03 | 6588/8192  | 14/30 | ✓      |
| D    |            40 | 32768 | q8_0 | q8_0 | more VRAM headroom        | 27.93 | 5890/8192  | 15/30 | ✓      |
| E    |            38 | 65536  | q8_0   | q4_0   | upstream 65k baseline      | 23.86 | 7452/8192  | 14/30 | ✓      |
| F    |            38 | 65536  | turbo4 | turbo3 | TurboQuant 65k (5aeb2fdbe) | 29.42 | 6434/8192  | 14/30 | ✓      |
| G    |            38 | 131072 | turbo4 | turbo3 | TurboQuant 131k stretch    | 24.50 | 7886/8192  | 14/30 | ⚠ OOM on >40k prompt fill |

## How to run each test

```bash
# Test A — baseline (fastest so far)
N_CPU_MOE=38 CTX=16384 sbatch server-speedrun-rtx3070.sbatch

# Test B — 32k context, VRAM near max
sbatch server-speedrun-rtx3070.sbatch

# Test C — isolate: same N_CPU_MOE as A, 32k context
N_CPU_MOE=38 CTX=32768 sbatch server-speedrun-rtx3070.sbatch

# Test D — more VRAM headroom at 32k
N_CPU_MOE=40 CTX=32768 sbatch server-speedrun-rtx3070.sbatch

# Test E — upstream 65k baseline
N_CPU_MOE=38 CTX=65536 CTK=q8_0 CTV=q4_0 sbatch server-speedrun-rtx3070.sbatch

# Test F — TurboQuant 65k (requires TurboQuant build)
N_CPU_MOE=38 CTX=65536 CTK=turbo4 CTV=turbo3 sbatch server-speedrun-rtx3070.sbatch

# Test G — TurboQuant 131k stretch (demo only; OOM on >40k prompt fill)
N_CPU_MOE=38 CTX=131072 CTK=turbo4 CTV=turbo3 sbatch server-speedrun-rtx3070.sbatch
```

Then benchmark:

```bash
bash scripts/benchmark_speedrun.sh <port>
```

## How to capture VRAM / RAM

```bash
# VRAM
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader

# RAM
free -h

# Memory lock
PID=$(pgrep -f llama-server | head -n1)
grep -E 'VmLck|VmRSS|VmSize' /proc/$PID/status
```

## Notes

<!-- Add observations after each test run -->

## Findings

- Best upstream balanced config: Test C — `N_CPU_MOE=38 CTX=32768 CTK=q8_0 CTV=q8_0`, about 31 tok/s, 80% VRAM.
- `N_CPU_MOE=34` is too aggressive for 32k: VRAM reaches ~97%.
- `N_CPU_MOE=40` offloads too much to CPU and drops speed to ~28 tok/s.
- Best long-context config: Test F — `N_CPU_MOE=38 CTX=65536 CTK=turbo4 CTV=turbo3`, about 29.4 tok/s, 78% VRAM.
- 131k TurboQuant works as a stretch test but is not stable for large prompt fill; it reached ~96% VRAM and OOMed on >40k prompt fill.
