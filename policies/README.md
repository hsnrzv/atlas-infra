# Policies

Policy checks that every change to this repository must pass. Enforced checks run in
[`manifests-ci`](../.github/workflows/manifests-ci.yml) on every pull request and on pushes to `main`, and locally via
[`scripts/validate.sh`](../scripts/validate.sh).

## Enforced now (Phase 1)

| Check | Tool | Rule | Where |
|---|---|---|---|
| Overlays render | `kubectl kustomize` | every `environments/*/kustomization.yaml` builds | `scripts/validate.sh` |
| Schema validation | kubeconform v0.8.0, `-strict`, Kubernetes 1.37.0 schemas | every rendered object and every `argocd/` manifest matches its schema; unknown fields fail. Argo CD CRD schemas come from a pinned commit of `datreeio/CRDs-catalog` | `scripts/validate.sh` |
| Image tag policy | `scripts/validate.sh` | every image has an explicit tag; `latest` is forbidden in every environment | `scripts/validate.sh` |
| Prod digest policy | `scripts/validate.sh` | prod images must be pinned with `@sha256:<digest>`; the only exception is the explicit placeholder tag `0.0.0-unreleased` used before the first release | `scripts/validate.sh` |
| No Secrets in Git | `scripts/validate.sh` | no rendered object of `kind: Secret` | `scripts/validate.sh` |
| Compose validity | `docker compose config -q` | `local/compose.yaml` is valid | CI |
| Shell lint | shellcheck v0.11.0 | `scripts/*.sh` clean | CI |
| YAML lint | yamllint 1.38.0 | `.yamllint.yaml` rules, warnings fail (`--strict`) | CI |
| Review | CODEOWNERS + branch protection (to configure on GitHub) | every change reviewed; prod paths owned explicitly | GitHub |

Run all of it locally (kubeconform/shellcheck/yamllint optional locally):

```bash
scripts/validate.sh
REQUIRE_KUBECONFORM=1 scripts/validate.sh   # same strictness as CI
```

## Baseline the manifests already follow (reviewed, not yet machine-enforced)

- Pod Security Admission `restricted` is enforced by labels on every environment Namespace, so the API server itself
  rejects pods that run as root, allow privilege escalation, keep capabilities or lack a seccomp profile.
- Every container: resource requests and limits; startup, readiness and liveness probes; read-only root filesystem
  with `emptyDir` only where writes are needed; `runAsNonRoot` with fixed UIDs; `capabilities.drop: [ALL]`;
  `seccompProfile: RuntimeDefault`; no service-account token automount.
- Namespace-wide default-deny ingress NetworkPolicy plus explicit allow rules per workload.
- No PostgreSQL exposed through the Ingress; the Ingress routes only `/api` and `/`.

## Planned (proposed, not implemented)

| Check | Proposed tool | Phase | Notes |
|---|---|---|---|
| Machine-enforced workload rules (the baseline above) | Kyverno CLI or Conftest in CI; optionally Kyverno admission in the cluster | 2–4 | Choose one engine; avoid duplicating Pod Security Admission |
| Image signature / provenance verification | cosign verification of GHCR images (keyless, GitHub OIDC) | 4+ | Requires signing in the backend/frontend container workflows first |
| Deprecated API detection before cluster upgrades | kubeconform against the target Kubernetes version | with each upgrade | Change `KUBERNETES_VERSION` in CI |
| Secret scanning | GitHub secret scanning + push protection (repository setting) | 1 (setting) | Enable when the GitHub repository is created |
| Argo CD AppProject drift | review rule: new resource kinds must be added to `argocd/projects/atlas.yaml` in the same PR | now (review) | kubeconform already validates the AppProject schema |
