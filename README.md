# atlas-infra

Infrastructure and GitOps repository for **IKIGAI ATLAS**. It holds the Kubernetes manifests (Kustomize), the Argo CD
project and application definitions, the local full-stack Docker Compose setup, validation scripts and CI, and the
infrastructure plan, cost comparison, runbooks and ADRs.

> **Status: Phase 0 planning + Phase 1 foundations.** Nothing in this repository is applied to a cluster yet.
> The Kubernetes platform (k3s on a VM vs AKS), the Azure region and subscription type, database hosting and
> secret management are open decisions. See [docs/adr/](docs/adr/README.md) and
> [docs/plan/PLAN-INFRASTRUCTURE-CICD.md](docs/plan/PLAN-INFRASTRUCTURE-CICD.md).

## Repository map

| Repository | Purpose | Image |
|---|---|---|
| [`atlas`](https://github.com/hsnrzv/atlas) | Angular frontend (+ Capacitor mobile later), design package, cross-repo docs and roadmap | `ghcr.io/hsnrzv/atlas-frontend` |
| [`atlas-microservices`](https://github.com/hsnrzv/atlas-microservices) | Spring Boot backend (a modular monolith despite the historical repo name) | `ghcr.io/hsnrzv/atlas-backend` |
| **`atlas-infra`** (this repo) | Local full stack, Kubernetes/GitOps manifests, Argo CD, infra CI, infra docs | — |

The local full stack expects all three repositories to be checked out side by side:

```text
project-atlas/
  atlas/                 # frontend (Dockerfile at repo root)
  atlas-microservices/   # backend  (Dockerfile at repo root)
  atlas-infra/           # this repo
```

## Prerequisites

| Tool | Used for | Notes |
|---|---|---|
| Docker Engine / Docker Desktop with Compose v2 | local full stack | `docker compose version` |
| `kubectl` (bundled Kustomize) **or** standalone `kustomize` | rendering overlays | any recent kubectl; CI pins v1.37.2 |
| `kubeconform` (optional locally) | schema validation | CI pins v0.8.0 with checksum; skipped locally with a warning if missing |
| `shellcheck`, `yamllint` (optional locally) | linting | CI pins shellcheck v0.11.0 and yamllint 1.38.0 |

No cloud CLI, credentials or cluster access are needed for anything in this repository today.

## Quick start: local full stack

```bash
# from the atlas-infra repository root
docker compose -f local/compose.yaml up --build -d
open http://127.0.0.1:8000/                    # frontend through the edge proxy
curl -fsS http://127.0.0.1:8000/actuator/health # backend health through the edge proxy
docker compose -f local/compose.yaml down       # stop (add -v to also delete the database volume)
```

The stack is PostgreSQL 18 + backend + frontend + an `edge` nginx that routes `/api/` to the backend and `/` to the
frontend, mirroring the Kubernetes Ingress. Everything binds to `127.0.0.1` only. Details, ports and troubleshooting:
[local/README.md](local/README.md) and [docs/runbooks/local-development.md](docs/runbooks/local-development.md).

## Validation commands

```bash
scripts/validate.sh                                  # render every overlay, image policy, kubeconform (if installed)
REQUIRE_KUBECONFORM=1 scripts/validate.sh            # what CI runs: fail if kubeconform is missing
kubectl kustomize environments/dev                   # inspect one rendered environment
docker compose -f local/compose.yaml config -q       # validate the compose file
yamllint --strict -c .yamllint.yaml .                # YAML style (CI)
shellcheck scripts/*.sh                              # shell lint (CI)
```

`scripts/validate.sh` fails on: render errors, images without an explicit tag, any `latest` tag, prod images that are
not digest-pinned (the explicit placeholder `0.0.0-unreleased` is tolerated until the first release), any rendered
`Secret`, and schema violations. See [policies/README.md](policies/README.md).

## Structure

```text
apps/
  backend/base/            Deployment, Service, ServiceAccount, NetworkPolicies, ConfigMap generator
  frontend/base/           Deployment, Service, NetworkPolicies
  ingress/base/            Ingress: /api -> atlas-backend, / -> atlas-frontend, TLS secret `atlas-tls`
  namespace-baseline/base/ default-deny ingress NetworkPolicy for every environment namespace
environments/
  dev/ staging/ prod/      overlays: Namespace (Pod Security `restricted`), replicas, resources, host, image pins
argocd/
  projects/atlas.yaml      AppProject: this repo only, three namespaces, whitelisted kinds
  applications/            atlas-dev (automated sync), atlas-staging and atlas-prod (manual sync)
local/                     Docker Compose full stack + edge nginx config
policies/                  policy checks (what is enforced now, what is planned)
scripts/validate.sh        render + validate all overlays
docs/
  plan/                    PLAN-INFRASTRUCTURE-CICD.md
  architecture/            COST-COMPARISON.md
  runbooks/                operational runbooks
  adr/                     architecture decision records
```

There is intentionally no `apps/postgres/`: production PostgreSQL is assumed to be a managed service
(Azure Database for PostgreSQL Flexible Server, [ADR-0004](docs/adr/0004-database-hosting.md), Proposed). A
self-hosted database would only be added there together with a tested backup/restore runbook.

## Environments

| Environment | Where | Namespace | Argo CD sync | Replicas (backend/frontend) |
|---|---|---|---|---|
| `local` | Docker Compose on a developer machine | — | — | 1/1 |
| `dev` | shared cluster (platform open) | `atlas-dev` | automated, prune + self-heal | 1/1 |
| `staging` | shared cluster (platform open) | `atlas-staging` | manual | 1/1 |
| `prod` | isolated as strongly as budget allows | `atlas-prod` | manual | 2/2 (+ PodDisruptionBudgets) |

Namespaces are organisational boundaries, not a complete security boundary; sharing one cluster between environments
is a documented cost trade-off, not equivalent to separate clusters.

## Promotion flow (summary)

`PR → CI → merge to main → image published to GHCR → automated PR bumps dev tag → Argo CD auto-syncs dev →
integration tests → release tag → PR promotes the same tag+digest to staging → manual sync → PR promotes to prod
(digest-pinned, CODEOWNERS review) → manual sync`.

Production is never deployed because a feature branch merged. Full details:
[docs/plan/PLAN-INFRASTRUCTURE-CICD.md](docs/plan/PLAN-INFRASTRUCTURE-CICD.md) and
[ADR-0007](docs/adr/0007-image-publishing-and-promotion.md).

## Secrets contract

No Secret is committed to this repository (enforced by `scripts/validate.sh`). The manifests reference:

| Secret | Namespace | Keys | Consumer | Source (Proposed, [ADR-0005](docs/adr/0005-secrets-management.md)) |
|---|---|---|---|---|
| `atlas-backend-db` | each `atlas-<env>` | `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` | backend Deployment | External Secrets Operator ← Azure Key Vault |
| `atlas-tls` | each `atlas-<env>` | `tls.crt`, `tls.key` | Ingress | cert-manager (Proposed) or manual import |

Until the secret-management decision is implemented, the backend pods will not start in a cluster (missing
`atlas-backend-db`), which is intentional: there is no fallback to committed credentials.

## Links

- Infrastructure & CI/CD plan: [docs/plan/PLAN-INFRASTRUCTURE-CICD.md](docs/plan/PLAN-INFRASTRUCTURE-CICD.md)
- Cost comparison (Azure retail prices, 2026-11-12): [docs/architecture/COST-COMPARISON.md](docs/architecture/COST-COMPARISON.md)
- ADRs: [docs/adr/README.md](docs/adr/README.md) · Runbooks: [docs/runbooks/README.md](docs/runbooks/README.md)
- Cross-repo roadmap and system context live in `atlas`: `docs/plan/IMPLEMENTATION-ROADMAP.md`,
  `docs/architecture/CONTEXT.md` (see `atlas` ADR-0002, repository topology)
- Contributing: [CONTRIBUTING.md](CONTRIBUTING.md) · Security: [SECURITY.md](SECURITY.md) ·
  Third-party tools: [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)

## License

No LICENSE file is included: the license is an open owner decision (tracked in the plan's open decisions).
