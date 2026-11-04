# Architecture: Kong API Gateway on Kubernetes

## Components

| Component | Choice | Why |
|---|---|---|
| Gateway | Kong Gateway, DB-less | No database to run; config comes from Kubernetes objects |
| Controller | Kong Ingress Controller | Turns `Ingress`, `KongPlugin` and `KongConsumer` objects into Kong config |
| Auth | `key-auth`, keys in labelled Secrets | Simple, per-consumer identity; `hide_credentials` stops keys reaching backends |
| Traffic control | `rate-limiting` (per consumer), `request-size-limiting` | Protects backends from abuse and oversized payloads |
| Tracing | `correlation-id` (`X-Request-ID`) | Same ID in gateway logs, backend logs and the client response |
| Audit | `file-log` to stdout | One JSON line per request, collected by Loki, Splunk or CloudWatch |
| Metrics | `prometheus` plugin + ServiceMonitor | Request rate, errors and latency per route and consumer |

## Request flow

1. The client calls `/payments` with an `apikey` header.
2. `key-auth` matches the key to a consumer (`partner`) or returns 401.
3. `rate-limiting` checks the consumer's budget (10/minute on payments) or returns 429.
4. `request-size-limiting` rejects bodies over 1 MB with 413.
5. `correlation-id` adds `X-Request-ID`; the request is proxied with `/payments` stripped.
6. `file-log` and `prometheus` record the result.

## Design decisions

- **Route-level vs global plugins.** Auth and limits differ per route, so they're attached by annotation.
  Request IDs, metrics and audit logs apply to everything, so they're `KongClusterPlugin`s labelled `global: "true"`.
- **Limit by consumer, not IP.** Partners behind one NAT would otherwise share a limit; by consumer is also fairer.
- **`policy: local` for the lab.** Each Kong replica counts separately. Production should use `redis` so limits hold
  across replicas.
- **DB-less mode.** Fewer moving parts and fully declarative; the trade-off is no Admin API writes at runtime.

## Security

- API keys never reach backends (`hide_credentials: true`).
- The keys in `03-consumers.yaml` are demo values. Real keys belong in a secret manager (External Secrets, Vault).
- Backends run non-root with read-only filesystems and are reachable only through Kong.

## Production hardening (next steps)

- TLS on the proxy with cert-manager, and OIDC or JWT auth for user-facing APIs.
- Redis-backed rate limiting; a NetworkPolicy so backends accept traffic only from Kong.
- The Gateway API (`HTTPRoute`) instead of `Ingress`, which KIC fully supports.
- Ship audit logs with `http-log` straight to a SIEM with retention policies.
