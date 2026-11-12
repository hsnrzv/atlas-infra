# Third-party notices

`atlas-infra` contains no application code and redistributes no third-party binaries. The table lists the third-party
software this repository *references or downloads at run time* (container images, CI tools, GitHub Actions, schemas),
with its concrete use, the version pinned here, and its license. Licenses were checked on 2026-11-12 from the
projects' GitHub repository metadata unless noted. Versions marked *proposed* are not installed anywhere yet.

## Container images (local stack)

| Component | Use | Version pinned | License |
|---|---|---|---|
| PostgreSQL (`postgres` official image) | local database in `local/compose.yaml` | `postgres:18.6-alpine` | PostgreSQL License (database); image packaging by `docker-library/postgres`: MIT |
| nginx (`nginx` official image) | `edge` reverse proxy in `local/compose.yaml` | `nginx:1.30-alpine` | BSD-2-Clause |

Application images (`ghcr.io/hsnrzv/atlas-backend`, `ghcr.io/hsnrzv/atlas-frontend`) and their base images are built
and documented in the `atlas-microservices` and `atlas` repositories.

## Tools (local and CI)

| Component | Use | Version pinned (CI) | License |
|---|---|---|---|
| kubectl (bundled Kustomize) | render overlays in `scripts/validate.sh` | v1.37.2 (checksum-verified) | Apache-2.0 |
| Kustomize (standalone, optional) | alternative renderer | not pinned (optional) | Apache-2.0 |
| kubeconform | strict schema validation | v0.8.0 (checksum-verified) | Apache-2.0 |
| Kubernetes JSON schemas (`yannh/kubernetes-json-schema`, kubeconform default location) | schemas for core kinds, Kubernetes 1.37.0 | fetched at run time | to verify (GitHub reports no SPDX identifier); derived from the Kubernetes OpenAPI spec (Apache-2.0) |
| CRDs catalog (`datreeio/CRDs-catalog`) | Argo CD `Application` / `AppProject` schemas | commit `89c736bdde38b5fecd0f8436ec5f3aa3679a3b86` | MIT |
| ShellCheck | lint `scripts/*.sh` (CI tool only, not distributed) | v0.11.0 (checksum-verified) | GPL-3.0 |
| yamllint | YAML lint (CI tool only, not distributed) | 1.38.0 | GPL-3.0 |
| pipx | runs yamllint in CI (preinstalled on GitHub runners) | runner-provided | MIT |
| Docker Compose | local stack, `config -q` validation | runner/desktop-provided | Apache-2.0 |

## GitHub Actions

| Action | Use | Version | License |
|---|---|---|---|
| `actions/checkout` | check out the repository | `@v7` | MIT |
| `actions/upload-artifact` | upload rendered manifests | `@v7` | MIT |

## Proposed platform components (not deployed; see ADRs)

| Component | Proposed use | Latest release seen (2026-11-12) | License |
|---|---|---|---|
| Argo CD | GitOps controller ([ADR-0002](docs/adr/0002-gitops-argocd-kustomize-separate-infra-repo.md)) | v3.6.1 (2026-11-04) | Apache-2.0 |
| k3s | Kubernetes distribution if the VM option is chosen ([ADR-0003](docs/adr/0003-kubernetes-platform.md)) | v1.37.2+k3s1 (2026-11-03) | Apache-2.0 |
| Traefik | ingress controller bundled with k3s | bundled with k3s | MIT |
| External Secrets Operator | sync Azure Key Vault secrets ([ADR-0005](docs/adr/0005-secrets-management.md)) | v2.15.0 (2026-11-10) | Apache-2.0 |
| cert-manager | TLS certificates for the Ingress (optional) | v1.21.3 (2026-10-23) | Apache-2.0 |
| SOPS (alternative) | encrypted secrets in Git (not recommended) | v3.13.3 (2026-07-23) | MPL-2.0 |
| Sealed Secrets (alternative) | encrypted secrets in Git (not recommended) | v0.41.2 (2026-10-26) | Apache-2.0 |
