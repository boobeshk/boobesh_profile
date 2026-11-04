# Architecture: Boomi Molecule on Kubernetes

## Components

| Component | Choice | Why |
|---|---|---|
| Runtime | Boomi Molecule as a StatefulSet | Each node needs a stable ID (`ATOM_LOCALHOSTID` = pod name) |
| Discovery | Headless Service | Stable DNS per node; the Molecule cluster coordinates through shared storage |
| Storage | One `ReadWriteMany` volume at `/mnt/boomi` | All nodes share one installation, config and process cache |
| Registration | Installer token from a Kubernetes Secret | Nodes register on first start; no credentials in the image |
| Scaling | HPA on CPU 2–6, one pod removed per 10 minutes at most | Integration load is bursty; slow scale-down avoids killing busy nodes |
| Shutdown | `terminationGracePeriodSeconds: 900` | Long-running processes (batch files, ERP syncs) can finish |
| Availability | Anti-affinity across hosts + PDB `minAvailable: 1` | A node failure or drain never stops every runtime |
| Delivery | Platform API: `PackagedComponent` → `DeployedPackage` | Versioned, repeatable releases from CI instead of manual clicks |
| Monitoring | `ExecutionRecord/query` for status `ERROR` | Failures surface in alerting, not just in the Boomi console |

## Release flow

1. A developer finishes a process in Boomi.
2. CI runs `deploy_package.py`, which creates an immutable package (for example version `1.4.0`, with release notes).
3. The same script deploys that package to the target environment (Test, then Prod).
4. Every Molecule node attached to that environment picks up the new version automatically.
5. `failed_executions.py` runs on a schedule; a non-zero exit alerts the team with the process name and error.

## Design decisions

- **StatefulSet, not Deployment.** Node identity must survive restarts; random pod names would register new nodes each time.
- **Shared RWX storage is required.** It's how Molecule nodes share state. Performance of this volume
  (NFS, EFS, Azure Files) directly affects process speed, so size and monitor it.
- **Package once, deploy many.** The same package ID goes to Test and Prod, so Prod runs exactly what was tested.
- **API token auth.** Token users can be revoked without changing a person's password, and their actions are audited.

## Production hardening (next steps)

- Store the installer token and API token in a secret manager (External Secrets with AWS Secrets Manager or Key Vault).
- Ship Molecule logs from `/mnt/boomi/logs` to Loki or Splunk; alert on Molecule node status through the API.
- Separate Molecules (or at least environments) for Test and Prod, with NetworkPolicies limiting egress to known endpoints.
- Run `failed_executions.py` as a Kubernetes CronJob and post results to Slack or Teams.
