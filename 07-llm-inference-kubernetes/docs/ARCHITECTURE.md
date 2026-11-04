# Architecture: LLM Inference Platform on Kubernetes

## Components

| Component | Choice | Why |
|---|---|---|
| Model server | Ollama 0.5.7, `llama3.2:1b` | Runs on CPU, simple HTTP API; a 1B model fits a lab cluster |
| Model storage | `emptyDir` per pod (10 Gi cap) | Every replica is self-contained, so scaling needs no shared volume |
| Scaling | HPA on CPU, 1–4 replicas, 10-minute scale-down window | Inference is CPU-bound here; slow scale-down avoids reloading the model |
| Availability | PDB `maxUnavailable: 1` | Node drains never take every replica at once |
| Gateway | Kong: key-auth, rate-limiting, request-size-limiting, request-termination | Identity, cost control and a small attack surface |
| Isolation | NetworkPolicy: ingress only from the `kong` namespace | No path to the model that bypasses the gateway |

## Request flow

1. A client sends `POST /api/chat` with an `apikey` header to Kong.
2. Kong checks the key (401), the consumer's rate (429) and the body size (413).
3. Allowed requests reach the `ollama` Service, which routes only to **ready** pods: pods whose model is loaded.
4. Any other `/api/*` path (for example `/api/pull`) matches the blocking route and gets a 403 from Kong.
5. Kong records metrics and an audit line (see labs 06 and 08).

## Probe design

| Probe | Check | Purpose |
|---|---|---|
| Startup | model appears in `ollama list`, up to 10 minutes | Allows a slow first download without restarts |
| Readiness | same check, every 10 s | Traffic only goes to replicas that can answer |
| Liveness | `GET /` on port 11434 | Restarts a hung server process |

## Design decisions

- **Pull at start-up instead of baking the model into the image.** Keeps the image small and the model swappable
  through one environment variable. For faster scale-out, bake the model into a custom image or pre-pull it to nodes.
- **Exact routes plus a catch-all block.** An allow-list is safer than trying to block known-bad paths.
- **Limit by consumer.** Each client app gets its own budget, which also makes per-team cost reporting possible.

## Limitations and next steps

- Kong's `file-log` records metadata, not prompts. Full prompt and response auditing needs Kong's AI plugins
  (`ai-proxy` with payload logging) or a logging sidecar, with privacy review.
- GPU nodes (NVIDIA device plugin, `nvidia.com/gpu` requests) for larger models, and KEDA scaling on queue
  depth or tokens per second instead of CPU.
- The container runs as root because the upstream image stores models under `/root`. A custom image with a
  non-root user would remove that.
