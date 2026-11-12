# ADR-0006: Frontend hosting — nginx container behind the same Ingress

- Status: Proposed
- Date: 2026-11-12
- Deciders: Repository owner (@hsnrzv) — decision pending; platform engineering (recommendation)

## Context

The Angular frontend is a static single-page application. §21 item 4 asks whether to serve it as a container behind
the Kubernetes Ingress or from static web hosting, and, if static hosting is chosen, how Argo CD fits. The
cross-repo contract already defines a frontend container: `nginxinc/nginx-unprivileged:1.30-alpine` on port 8080,
SPA fallback, `GET /healthz`, image `ghcr.io/hsnrzv/atlas-frontend`. The API is served under `/api/v1` by the
backend; routing `/api/` → backend and `/` → frontend is the contract for both the local edge and the Ingress.

## Decision

Recommended default (awaiting owner approval): **serve the frontend as an nginx-unprivileged container in the same
cluster, behind the same Ingress and host as the backend** (`/api` → `atlas-backend`, `/` → `atlas-frontend`).

- Implemented in Phase 1 as manifests (`apps/frontend/base`, `apps/ingress/base`): non-root UID 101, read-only root
  filesystem with `emptyDir` for `/tmp` and `/var/cache/nginx`, `/healthz` probes, no egress.
- The frontend image is promoted exactly like the backend image (immutable tag + digest, PR to this repo,
  [ADR-0007](0007-image-publishing-and-promotion.md)).

## Consequences

- One deployment model (Argo CD) and one promotion flow for both workloads; frontend and backend versions are pinned
  together per environment and roll back together.
- Same-origin API calls: no CORS configuration, cookies (for a future BFF/session approach, §13.1) stay first-party.
- Negligible cluster cost (requests 10m CPU / 32 Mi memory per replica).
- No CDN; for a single user this is irrelevant. Static assets are served from the cluster's region.
- The frontend's availability equals the cluster's availability.

## Alternatives considered

- **Azure Static Web Apps** (Free: 0 €, no SLA; Standard: 8.08 € per app-month, only priced in West Europe;
  retrieved 2026-11-12). Global static hosting and free TLS, but a second deployment mechanism outside Argo CD:
  deployments would be GitHub Actions uploads, and Argo CD would only manage the backend. Cross-origin API calls
  (or a linked backend) would be needed. To keep GitOps, the frontend version could still be recorded in this repo
  and deployed by a workflow triggered from it, but Argo CD would not reconcile or roll it back.
- **Azure Blob static website + CDN/Front Door.** Same split-deployment issue; extra components for TLS on a custom
  domain.
- **Bundle the frontend into the backend jar.** Couples release cycles of two repositories; rejected by the repository
  topology (see `atlas` ADR-0002 (repository topology)).

## References

- Microsoft Learn, Static Web Apps hosting plans: https://learn.microsoft.com/en-us/azure/static-web-apps/plans (accessed 2026-11-12)
- [COST-COMPARISON.md](../architecture/COST-COMPARISON.md)
- project-instruction.md §15.3, §21 item 4
