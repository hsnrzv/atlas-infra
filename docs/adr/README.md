# Architecture decision records (atlas-infra)

Decisions about infrastructure, deployment, CI/CD and operations for IKIGAI ATLAS. The process is defined in
[ADR-0001](0001-record-architecture-decisions.md); new records start from [0000-template.md](0000-template.md).

This repository numbers its own ADRs from 0001. Cross-cutting decisions (repository topology, UI stack, vocabulary)
live in the `atlas` repository; refer to them as e.g. "`atlas` ADR-0002 (repository topology)". Backend-internal
decisions live in `atlas-microservices/docs/adr/`.

| ADR | Title | Status | Date |
|---|---|---|---|
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted | 2026-11-12 |
| [0002](0002-gitops-argocd-kustomize-separate-infra-repo.md) | GitOps with Argo CD and Kustomize in a separate `atlas-infra` repository | Accepted | 2026-11-12 |
| [0003](0003-kubernetes-platform.md) | Kubernetes platform: k3s on an Azure VM vs AKS Free/Standard | Accepted (prod as a namespace on the same VM) | 2026-11-12 |
| [0004](0004-database-hosting.md) | Database hosting: Azure Database for PostgreSQL Flexible Server vs self-hosted | Accepted | 2026-11-12 |
| [0005](0005-secrets-management.md) | Production secrets: External Secrets Operator + Azure Key Vault | Proposed | 2026-11-12 |
| [0006](0006-frontend-hosting.md) | Frontend hosting: nginx container behind the same Ingress | Proposed | 2026-11-12 |
| [0007](0007-image-publishing-and-promotion.md) | Image publishing and promotion: GHCR, immutable tags + digests, PR-based promotion | Accepted | 2026-11-27 |
| [0008](0008-database-migration-execution.md) | Database migration execution strategy | Proposed | 2026-11-12 |
| [0009](0009-azure-services-and-free-tier.md) | Azure services for the production MVP and use of the free tier | Accepted | 2026-11-12 |

## Status meanings

- **Proposed**: a recommendation that awaits the owner's decision. Nothing that depends on it has been created
  outside this repository (no cloud resources, no cluster).
- **Accepted**: a user decision or a baseline already implemented in Phase 1.
- **Superseded by ADR-NNNN**: kept for history; the newer ADR explains what changed.

To accept or change a Proposed ADR, open a PR that updates its status (and the decision text if it changed), and
update this index in the same PR.
