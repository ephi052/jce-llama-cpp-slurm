# SSH Tunnel Setup

Connect to the llama.cpp server running on a SLURM compute node from your local machine.

## 1. Find the compute node

Check the server log for the node name:

```bash
grep "Node:" llama_server_*.log
```

Or check running jobs:

```bash
squeue -u $USER -o "%.10i %.20j %.8T %.10R"
```

## 2. Create the SSH tunnel

From your **local machine**, tunnel through the JCE login node:

```bash
ssh -L 8080:<compute-node>:8080 <username>@hpc-master
```

For an additional server run on a different node/port (example port 8082):

```bash
ssh -L 8082:<compute-node>:8082 <username>@hpc-master
```

Example:

```bash
ssh -L 8080:HPC-RTX3070-09:8080 ephraimco@hpc-master
```

Replace `<compute-node>` and `<username>` with your values.

## 3. Access the server

If your network can reach the compute node directly, you can also access it at:

```bash
http://<compute-node>:8080
```

Otherwise, use the SSH tunnel above and access `localhost`.

| What | URL |
|------|-----|
| Web UI | http://localhost:8080 |
| Health check | http://localhost:8080/health |
| Chat completions | http://localhost:8080/v1/chat/completions |
| Models list | http://localhost:8080/v1/models |

If you run multiple servers, use matching ports (for example `8081`, `8082`) in both
the SSH tunnel and the request URL.

## 4. Test with curl

```bash
# Health check
curl http://localhost:8080/health

# Chat completion
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello!"}],
    "temperature": 0.7
  }'

# Streaming
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Count to 10"}],
    "stream": true
  }'
```

## 5. Use with Python (OpenAI SDK)

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:8080/v1", api_key="not-needed")

response = client.chat.completions.create(
    model="model",
    messages=[{"role": "user", "content": "Hello!"}]
)
print(response.choices[0].message.content)
```

## Tips

- **Background the tunnel**: `ssh -fNL 8080:<compute-node>:8080 user@hpc-master`
- **Direct access** only works if the compute node is reachable from your machine and the port is not blocked by firewall or cluster policy.
- **Stop the server**: `scancel <job_id>`
- If logs show `CUDA error: no kernel image is available for execution on the device`, rebuild llama.cpp with multi-arch CUDA targets (see [README.md](../README.md)).
