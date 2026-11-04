# Architecture: Kubernetes Observability Stack

## Components

| Signal | Tool | Notes |
|---|---|---|
| Metrics | Prometheus (kube-prometheus-stack) | 15-day retention on a 20 Gi volume; scrapes ServiceMonitors in every namespace |
| Cluster state | kube-state-metrics, node-exporter | Included in the stack: pods, deployments, nodes, disks |
| Logs | Loki single binary + Grafana Alloy | Alloy tails pods through the Kubernetes API and adds namespace/pod/container/app labels |
| Dashboards | Grafana with sidecar | Any ConfigMap labelled `grafana_dashboard=1` becomes a dashboard |
| Alerts | Alertmanager → Slack | Grouped by alert and namespace; the Watchdog heartbeat goes to a null receiver |

## The SLO

- **SLI:** share of podinfo requests that don't return 5xx.
- **Target:** 99.9% over 30 days, so the **error budget is 0.1%** of requests (about 43 minutes of full outage).

### Burn-rate alerts

A burn rate of 1 uses the budget in exactly 30 days. Alerts fire on how fast the budget is going, not on single errors.

| Alert | Burn rate | Long window | Short window | Budget used when it fires | Action |
|---|---|---|---|---|---|
| Fast burn | 14.4x | 1 h | 5 m | 2% in 1 hour | Page (critical) |
| Slow burn | 6x | 6 h | 30 m | 5% in 6 hours | Ticket (warning) |

The **long window** proves the problem is real. The **short window** makes the alert resolve quickly once
the problem is fixed. Both must be true to fire.

## Design decisions

- **Recording rules for error ratios.** Alerts and dashboards read cheap precomputed series instead of
  recalculating `rate()` over 6 hours on every evaluation.
- **Burn-rate alerts instead of "error rate > 1%".** Fixed thresholds page at night for blips and miss slow leaks.
  Burn rates tie every alert to user impact against the SLO.
- **Latency alert on p99 from histograms.** Averages hide tail latency; `histogram_quantile` over buckets shows it.
- **Alloy instead of Promtail.** Promtail is deprecated; Alloy is Grafana's supported collector for logs, metrics and traces.

## Production hardening (next steps)

- Loki and Prometheus long-term storage on object storage (S3, Azure Blob), or Thanos / Mimir for multi-cluster metrics.
- Route critical alerts to PagerDuty or Opsgenie with an on-call rotation; link every alert to a runbook.
- Add traces with OpenTelemetry and Tempo, and link logs, metrics and traces by request ID.
- Generate SLO rules with a tool such as Sloth or Pyrra to keep many SLOs consistent.
