# Architecture: Azure AKS with GitOps

## Components

| Component | Choice | Why |
|---|---|---|
| Network | VNet `10.30.0.0/16`, node subnet `/20`, Azure CNI | Pods get VNet IPs; works with NSGs and private endpoints |
| Network policy | Calico | Namespace-level isolation with standard `NetworkPolicy` objects |
| System pool | `Standard_D2s_v5`, 1–3 nodes, critical add-ons only | Keeps CoreDNS and the metrics server away from noisy apps |
| User pool | `Standard_D4s_v5`, 1–5 nodes | Application capacity that scales on its own |
| Identity | System-assigned managed identity, OIDC issuer, workload identity | No service principal secrets to rotate |
| Governance | Azure Policy add-on | Enforce rules such as "no privileged containers" across the cluster |
| Logs | Log Analytics + Container Insights, 30 days | Node, pod and container logs and metrics in one place |
| Delivery | Argo CD, app-of-apps | Git is the source of truth; drift is corrected automatically |

## GitOps flow

1. Terraform builds the cluster. Helm installs Argo CD. That's the only manual install.
2. `root-app.yaml` is applied once. It points Argo CD at `k8s/apps/`.
3. Every Application in `k8s/apps/` (here: podinfo) is created automatically.
4. Each Application syncs its folder under `k8s/workloads/`, with `prune` (delete what Git removed) and
   `selfHeal` (undo manual changes).
5. Adding a new service means adding one Application file and one workload folder, then pushing.

## Design decisions

- **App of apps.** One bootstrap object; everything else comes from Git, including new Applications.
- **Separate system and user pools.** `only_critical_addons_enabled` taints the system pool so app spikes can't starve DNS.
- **Retry with backoff.** Syncs that race CRD installs or webhooks retry automatically instead of failing.
- **Free control-plane tier for the lab.** Production should use the Standard tier for the uptime SLA.

## Security

- No secrets in Git. Workload identity lets pods get Entra ID tokens through federation.
- A NetworkPolicy allows traffic to podinfo only from its own namespace.
- Containers run non-root with a read-only filesystem and no Linux capabilities.

## Production hardening (next steps)

- Private cluster (API server not on the internet) with access through a jump host or VPN.
- Argo CD behind an ingress with TLS and SSO through Entra ID; restrict Argo CD projects per team.
- Sealed Secrets or the Secrets Store CSI driver with Azure Key Vault.
- Terraform state in an Azure Storage account with locking.
