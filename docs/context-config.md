# Context Size and Parallelism

## How it works

llama.cpp allocates a single KV cache of size `--ctx-size` tokens and divides it
evenly across `--parallel` slots. Each in-flight request occupies one slot:

```
tokens per request = ctx-size / parallel
```

## Tradeoff table

| `ctx-size` | `parallel` | Tokens per request | VRAM (KV cache est.) |
|-----------|------------|--------------------|-----------------------|
| 4096 | 1 | **4096** | ~224 MiB |
| 4096 | 4 | 1024 | ~224 MiB |
| 8192 | 1 | **8192** | ~448 MiB |
| 8192 | 4 | 2048 | ~448 MiB |
| 16384 | 1 | **16384** | ~896 MiB |
| 16384 | 4 | 4096 | ~896 MiB |

KV cache VRAM scales with `ctx-size × parallel` — increasing either costs VRAM.

## Defaults (env.sh)

```bash
DEFAULT_CONTEXT_SIZE=4096
DEFAULT_PARALLEL=1
# → 4096 tokens per request
```

## GPU limits (RTX 2080 SUPER, 8GB)

| ctx-size | parallel | Total VRAM (model + KV) | Feasible? |
|---------|----------|-------------------------|-----------|
| 4096 | 1 | ~4.6 GB | ✅ comfortable |
| 8192 | 1 | ~5.0 GB | ✅ fine |
| 16384 | 1 | ~5.7 GB | ✅ likely |
| 32768 | 1 | ~7.1 GB | ⚠️ tight |
| 4096 | 4 | ~4.6 GB | ✅ but only 1024 tok/req |

Model weights (Q4_K_M, 7B): ~4.36 GiB fixed. Remaining VRAM goes to KV cache.

## When to change

**Use higher context (`ctx-size 8192+`)** when:
- Prompts include long documents, code files, or chat history
- You hit "context length exceeded" errors
- Summarization / RAG tasks with large retrieved chunks

**Use higher parallel** when:
- Multiple users or clients hit the server concurrently
- Requests are short (chat completions, short Q&A)
- You can tolerate shorter per-request context

## Override at launch time

The `parallel` argument is positional in `server.sbatch`:

```bash
sbatch server.sbatch <model> <port> <parallel>

# Examples:
sbatch server.sbatch Qwen/Qwen2.5-7B-Instruct-GGUF:Q4_K_M 8080 1   # 4096 tok/req
sbatch server.sbatch Qwen/Qwen2.5-7B-Instruct-GGUF:Q4_K_M 8080 4   # 1024 tok/req
```

To change `ctx-size` permanently, edit `DEFAULT_CONTEXT_SIZE` in `env.sh`. To
rebuild `env.sh` with new defaults, re-run `build.sbatch` and edit the generated
values, or just edit `env.sh` directly (it is not tracked by git).
