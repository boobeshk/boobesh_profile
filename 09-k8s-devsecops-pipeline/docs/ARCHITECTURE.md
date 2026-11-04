# Architecture: Kubernetes DevSecOps Pipeline

## Pipeline stages

| Stage | Tool | Fails the build when |
|---|---|---|
| Secrets | gitleaks | A key, token or password is committed (whole Git history scanned) |
| Config | Checkov | Kubernetes or Dockerfile misconfiguration (root user, no limits, privilege escalation) |
| Build | Docker | Image doesn't build |
| Vulnerabilities | Trivy | A HIGH or CRITICAL CVE has a fix available |
| Publish | ECR via GitHub OIDC | Only on `main`; pull requests stop after scanning |
| Sign | cosign keyless (Sigstore) | Signing fails; the signature records the workflow identity in a public log |
| Deploy | kustomize + Argo CD | The new digest is committed; Argo CD syncs it |

## Threat model (what each control stops)

| Threat | Control |
|---|---|
| Leaked credentials in Git | gitleaks; OIDC instead of stored AWS keys |
| Known-vulnerable packages | Trivy gate, slim pinned base image |
| Image swapped in the registry | Deploy by digest; Kyverno verifies the Sigstore signature |
| Someone runs an unscanned image by hand | `verifyImages` rejects unsigned images in the namespace |
| Container breakout / privilege escalation | PSA `restricted`, non-root UID 10001, no capabilities, seccomp, read-only FS |
| Stolen service-account token | `automountServiceAccountToken: false` |
| Lateral movement inside the cluster | Default-deny NetworkPolicy; only the ingress controller may connect |
| Noisy neighbour | Kyverno requires CPU and memory limits |

## Design decisions

- **Two layers at admission.** Pod Security Admission is built in and covers pod-level hardening; Kyverno adds what
  PSA can't: image signatures, tag pinning and resource limits.
- **Keyless signing.** No signing key to store or rotate. The certificate binds the signature to this exact
  GitHub workflow, which the Kyverno policy checks.
- **`ignore-unfixed` in Trivy.** Failing on CVEs nobody can fix blocks every release; fixable ones must be fixed.
- **Pull requests scan but never publish.** Untrusted branches can't push images or sign anything.

## Production hardening (next steps)

- Generate an SBOM (Syft) and attach it as a signed attestation; verify it at admission.
- Add SAST (Semgrep or CodeQL) and dependency review on pull requests.
- Runtime detection with Falco; send policy reports to the security team.
- Restrict the IAM role's trust policy to the `main` branch of one repository.
