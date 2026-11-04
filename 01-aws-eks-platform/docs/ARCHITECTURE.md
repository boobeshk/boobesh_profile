# Architecture: AWS EKS Platform

## Components

| Component | Choice | Why |
|---|---|---|
| Network | VPC across 3 AZs, private + public subnets | Nodes stay private; load balancers live in public subnets |
| Egress | Single NAT gateway | Lowest lab cost (production: one per AZ) |
| Control plane | Amazon EKS 1.31 | Managed, highly available API server |
| Add-ons | CoreDNS, kube-proxy, VPC CNI, Pod Identity agent | Managed by EKS and upgraded with the cluster |
| Baseline nodes | Managed node group, on-demand `t3.large` | Predictable capacity for system pods |
| Burst nodes | Managed node group, spot, multiple instance types | Up to ~70% cheaper; several types reduce interruption risk |
| Workload | podinfo with HPA, PDB, probes | Demonstrates scaling, self-healing and safe node drains |

## Request flow

1. A client reaches an AWS load balancer in a public subnet.
2. The load balancer forwards to the `podinfo` Service, which routes to ready pods only (readiness probe).
3. Pods run on private nodes in any of the three AZs.
4. When average CPU passes 70%, the HPA adds pods (up to 10). If nodes are full, raise the node group size or add
   Cluster Autoscaler / Karpenter (see below).

## Design decisions

- **Spot behind a taint.** Spot nodes carry `lifecycle=spot:NoSchedule`. Only workloads that tolerate interruption
  add the toleration, so critical pods never land on spot by accident.
- **Topology spread over anti-affinity.** `ScheduleAnyway` spreads pods across zones without blocking scheduling
  when a zone is short on capacity.
- **PDB with `minAvailable: 1`.** Node upgrades and spot reclaims drain nodes one at a time without a full outage.
- **Cluster creator gets admin.** Simple for a lab. In production, map IAM roles to Kubernetes RBAC with EKS access entries.

## Security

- Worker nodes have no public IPs; outbound traffic goes through NAT.
- Containers run as non-root, with a read-only root filesystem, no privilege escalation and all capabilities dropped.
- Pod Identity agent is installed so pods can get scoped AWS credentials without node-wide IAM permissions.

## Production hardening (next steps)

- Restrict the public API endpoint to known CIDRs, or make it private only.
- Add Karpenter or Cluster Autoscaler for node-level scaling.
- Store Terraform state in S3 with DynamoDB locking.
- Add the AWS Load Balancer Controller and an Ingress with TLS from ACM.
- Turn on control-plane logging to CloudWatch.
