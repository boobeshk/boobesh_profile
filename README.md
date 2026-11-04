# Boobesh K · DevOps & Cloud Labs

**Senior DevOps Engineer | Site Reliability Engineer** · AWS · Azure · Kubernetes · Kong · Boomi

Ten hands-on labs covering how I design, automate, secure and run cloud platforms. Each lab has working code
(Terraform, Kubernetes manifests, Helm values, Python), an architecture diagram, and a design document explaining
the trade-offs.

> These are **hands-on labs and reference builds** for learning and demonstration. They are not client code and
> contain no client data. Everything can be deployed into a personal AWS or Azure account; each lab lists its cost.

[![Validate](https://github.com/boobeshk/boobesh_profile/actions/workflows/validate.yml/badge.svg)](https://github.com/boobeshk/boobesh_profile/actions/workflows/validate.yml)

## Labs

| # | Lab | Cloud / platform | Highlights |
|---|---|---|---|
| 01 | [AWS EKS Platform](01-aws-eks-platform) | AWS · Kubernetes | Terraform VPC + EKS, on-demand and spot node groups, HPA, PDB, multi-AZ spread |
| 02 | [AWS Serverless API](02-aws-serverless-api) | AWS | API Gateway → Lambda → DynamoDB, least-privilege IAM, throttling, X-Ray |
| 03 | [AWS FinOps Guardrails](03-aws-finops-guardrails) | AWS · FinOps | Budgets, anomaly detection, tag-gated EC2 scheduler, cost-by-tag report |
| 04 | [Azure AKS with GitOps](04-azure-aks-gitops) | Azure · Kubernetes | Terraform AKS, workload identity, Calico, Argo CD app-of-apps |
| 05 | [Azure Hub-and-Spoke Network](05-azure-hub-spoke-network) | Azure · Networking | Hub firewall, FQDN egress control, NSGs, UDRs, peering by `for_each` |
| 06 | [Kong Gateway on Kubernetes](06-kong-gateway-kubernetes) | Kong · Kubernetes | Key auth, per-consumer rate limits, request IDs, audit logs, Prometheus |
| 07 | [LLM Inference on Kubernetes](07-llm-inference-kubernetes) | Kubernetes · Kong · AI | Self-hosted LLM, model-aware probes, autoscaling, gateway governance |
| 08 | [Observability Stack with SLOs](08-k8s-observability-stack) | Kubernetes · SRE | Prometheus, Grafana, Loki, Alloy, multi-window burn-rate alerts |
| 09 | [DevSecOps Pipeline](09-k8s-devsecops-pipeline) | Kubernetes · Security | gitleaks, Checkov, Trivy, cosign keyless signing, Kyverno, PSA |
| 10 | [Boomi Molecule on Kubernetes](10-boomi-molecule-kubernetes) | Boomi · Kubernetes | Clustered runtime, graceful scaling, API-driven deploys, failure reports |

## Skills covered

| Area | Where |
|---|---|
| Infrastructure as Code (Terraform) | 01, 02, 03, 04, 05 |
| Kubernetes operations (EKS, AKS) | 01, 04, 06, 07, 08, 09, 10 |
| GitOps (Argo CD) | 04, 09 |
| API management (Kong) | 06, 07 |
| Observability and SRE (SLOs, alerting) | 08, plus metrics in 02, 06, 07 |
| DevSecOps and supply-chain security | 09, plus least-privilege IAM in 02, 03 |
| Networking and security | 05, plus NetworkPolicies in 04, 07, 09 |
| FinOps and cost optimisation | 03, plus spot capacity in 01 |
| Integration platforms (Boomi) | 10 |
| AI platform operations | 07 |

## How each lab is organised

```
NN-lab-name/
  README.md              what it is, diagram, how to run and clean up
  docs/ARCHITECTURE.md   components, flows, design decisions, security, next steps
  terraform/             infrastructure (where used)
  k8s/                   Kubernetes manifests
  helm/                  Helm values for third-party charts
  src/ app/ scripts/     application and automation code
```

## Quality checks

Every push runs [`validate.yml`](.github/workflows/validate.yml):

- `terraform fmt -check` and `terraform validate` on every Terraform folder
- `kubeconform` schema validation for all Kubernetes manifests, including CRDs (Argo CD, Kong, Kyverno, Prometheus Operator)
- Python syntax check on all scripts

## Conventions

- Pinned versions for providers, modules, charts and container images.
- No secrets in Git: demo values are clearly marked, and real values come from Secrets, OIDC or a vault.
- Secure defaults: non-root containers, read-only filesystems, least-privilege IAM, network policies.
- Every lab says what it costs and how to tear it down.

## License

[MIT](LICENSE) © 2026 Boobesh K
