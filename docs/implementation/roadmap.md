# Implementation roadmap — atlas-infra

- Status: **Proposed 2026-11-17**, awaiting owner approval. Phase 0 and Phase 1 are done (Gate 1 met 2026-11-27:
  `manifests-ci` green and required on `main`). Phase 2 is done for the backend (ADR-0007 accepted, backend images
  published, dev bump PRs auto-merge); the frontend publishing (INF-2.1, `atlas` F2-12) is open. Nothing has been applied to a cluster or created in Azure.
- Purpose: set the order in which the platform is built, with an explicit gate between phases, the cost gates, and
  the cross-repository hand-offs to `atlas` (frontend) and `atlas-microservices` (backend).
- Maps the cross-repository phases P0–P11 in `atlas` `docs/plan/IMPLEMENTATION-ROADMAP.md` onto the backlog in
  [PLAN-INFRASTRUCTURE-CICD § Backlog](../plan/PLAN-INFRASTRUCTURE-CICD.md#backlog-pr-sized). This roadmap gives
  those items stable `INF-<phase>.<n>` IDs (also shown in the plan). The plan stays authoritative for scope and
  acceptance criteria; this one sets the order, the gates and the dependencies.
- Related: [ADR index](../adr/README.md), [COST-COMPARISON](../architecture/COST-COMPARISON.md),
  [runbooks](../runbooks/README.md); siblings: `atlas` `docs/implementation/roadmap.md` (frontend),
  `atlas-microservices` `docs/implementation/roadmap.md` (backend, `BE-…` IDs).

## 1. Working rules

- **One backlog item per PR**, small and reviewable. Each PR names its `INF-…` ID.
- Every PR keeps `manifests-ci` green: `scripts/validate.sh` (kustomize render, kubeconform `-strict`, no `latest`,
  no rendered `Secret`), shellcheck, yamllint, `docker compose config`.
- **Cost gate:** no Azure resource is created before the owner explicitly approves Phase 3 and the subscription
  budget with alerts exists (INF-3.1 first). Prices are re-checked before each resource is created.
- **Exposure gate:** dev and staging stay allow-listed (NSG or tunnel) until Phase 9 authentication exists; prod
  only after the Phase 9 exit criteria.
- GitOps only: the cluster state changes through this repository and Argo CD, never by `kubectl apply` outside the
  documented bootstrap runbook. No secrets in Git (ESO pulls from Key Vault).
- Images are pinned by tag **and** digest; `latest` is never deployed. Staging and prod sync manually.
- Tools and actions are pinned (versions and checksums or commit SHAs); permissive licences only, recorded in
  `THIRD-PARTY-NOTICES.md`.

## 2. Phases

### Phase 1 — Foundations (repo P1 finish)

| ID | Item | Status |
|---|---|---|
| INF-1.1…1.9 | Hygiene, local full stack, Kustomize bases and overlays, Argo CD project and apps (not applied), `validate.sh`, `manifests-ci`, docs and ADRs, ADR-0009 | done 2026-11-12 (local) |
| INF-1.10 | First push and first green `manifests-ci` run on GitHub | done 2026-11-27: `manifests-ci` green on `main` and on the bump PRs |
| INF-1.11 | Branch protection on `main` requiring `manifests-ci`; Dependabot alerts; secret scanning with push protection | done 2026-11-27: ruleset `protect-main` requires `Render & validate manifests`; Dependabot and secret scanning set by the owner. Private vulnerability reporting enabled 2026-11-27 |

**Gate 1:** `manifests-ci` green on GitHub and required on `main` (together with `atlas` F1-15 and backend
BE-1.14/1.15, which closes repo P1).

### Phase 2 — Publishing (no cloud cost)

| ID | Item | Status |
|---|---|---|
| INF-2.0 | Owner decisions: ADR-0005 (secrets), 0006 (frontend hosting), 0007 (image publishing), 0008 (migrations) accepted or amended; region; domain; shared image scanner (Trivy proposed) | partly done 2026-11-27: ADR-0007 accepted (unblocks INF-2.1…2.3); Trivy runs in both application repositories. Open (owner): ADR-0005, 0006, 0008, region, domain, GHCR package visibility (needed by Phase 3) |
| INF-2.1 | `atlas` `frontend-container` publishes `main-<sha>` to GHCR with SBOM, provenance and scan (`atlas` F2-12) | open (unblocked 2026-11-27); SBOM and Trivy scan already run (F2-11) |
| INF-2.2 | `atlas-microservices` `backend-container` publishes `main-<sha>` to GHCR (BE-1.13, BE-2.4) | done 2026-11-27 |
| INF-2.3 | GitHub App for cross-repo PRs; bump-PR job in both container workflows targeting `environments/dev` | partly done 2026-11-27: App installed; backend `bump-infra-dev` opens `chore/bump-backend-dev` with auto-merge (squash) once `manifests-ci` passes (#2, #3). Open: the frontend bump job (`atlas` F2-12) |
| INF-2.4 | Optional: local kind/k3d rehearsal of the Argo CD Applications (documented, not CI) | open, optional |

**Gate 2:** a merge to `main` in each application repository produces a scanned, signed-provenance image in GHCR and
an automated bump PR here that passes `manifests-ci`. **Status 2026-11-27:** met for the backend; open for the
frontend (INF-2.1, F2-12).

### Phase 3 — Non-prod platform and dev environment (creates paid resources)

**Needs explicit owner approval** (≈ 61 EUR/month in the free year, ADR-0009) and the region confirmed. Order is
fixed: the budget comes first.

| ID | Item | Depends on | Status |
|---|---|---|---|
| INF-3.1 | Azure free account (pay-as-you-go within 30 days), budget 75 EUR with 50/80/100 % and anomaly alerts, `rg-atlas-nonprod` with tags | owner approval | open |
| INF-3.2 | Azure DNS public zone for the owner's domain; Private DNS zone for PostgreSQL | INF-3.1, domain | open |
| INF-3.3 | Cluster bootstrap runbook + pinned bootstrap (k3s, Argo CD, ESO, cert-manager) on the B2as_v2 VM; NSG allow-list | INF-3.1 | open |
| INF-3.4 | Non-prod PostgreSQL Flexible Server (`atlas_dev`, `atlas_staging`, separate logins, not public) | INF-3.2 | open |
| INF-3.5 | Non-prod Key Vault + `atlas-dev-secrets` (SecretStore, ExternalSecrets); AppProject whitelist update | INF-3.3, ADR-0005 | open |
| INF-3.6 | TLS: ClusterIssuer (DNS-01) + `atlas-tls` for dev; `ingressClassName` set | INF-3.2, INF-3.3 | open |
| INF-3.7 | Apply the AppProject and `atlas-dev`; first automated sync; verify probes and NetworkPolicies on the real controller | INF-3.4…3.6, Gate 2 | open |

**Gate 3:** `atlas-dev` is synced and healthy from Git, serves the frontend and `/api` over TLS to allow-listed
clients, reads its secrets from Key Vault, and the actual monthly run rate is within the budget.

### Phase 4 — Staging and promotion

Needs Gate 3 and backend Gate 3 (real endpoints and OpenAPI snapshot).

| ID | Item | Depends on | Status |
|---|---|---|---|
| INF-4.1 | `openapi-publish.yml` in `atlas-microservices` (BE-4.1) | backend Gate 3 | open |
| INF-4.2 | `atlas-staging` live (manual sync) with secrets and TLS | Gate 3 | open |
| INF-4.3 | PostSync smoke-test Job for staging (AppProject allows `batch/Job`) | INF-4.2 | open |
| INF-4.4 | `promote.yml`: promotion PR copying tag and digest dev → staging (later staging → prod) | INF-4.2 | open |
| INF-4.5 | e2e suite runs against staging with the agreed access model (backend R-2, BE-4.5; `atlas` F4-6) | INF-4.3, BE-4.5 | open |
| INF-4.6 | Rollback runbook + drill in staging (revert promotion, sync, verify) | INF-4.4 | open |
| INF-4.7 | Rendered-manifest diff on `atlas-infra` PRs | — (can start any time after Gate 1) | open |

**Gate 4:** repo phase-4 gate: e2e green in staging; promotion and rollback rehearsed; no demo-only data.

### Phases 5–8 — No planned infrastructure work

Artifact storage for exports (Phase 7) only if the export renderer needs it; decided in the Phase 7 spike.

### Phase 9 — Production

| ID | Item |
|---|---|
| INF-9.1 | Identity provider integrated (Entra External ID external tenant, sign-up disabled); no unauthenticated public route |
| INF-9.2 | Prod namespace on the shared VM: ResourceQuota on `atlas-dev`/`atlas-staging`, PriorityClass for prod |
| INF-9.3 | Prod PostgreSQL (35-day PITR), prod Key Vault, public TLS, HSTS/redirect; budget raised to 125 EUR |
| INF-9.4 | Uptime check of prod `/healthz` |
| INF-9.5 | Migration PreSync Job with a separate DDL role (staging first, then prod); backend migrate-only mode (ADR-0008) |
| INF-9.6 | Weekly `pg_dump` to Blob Cool; restore drill completed and timed; backup/restore runbook |
| INF-9.7 | Runbooks: secret rotation, teardown, cluster rebuild (rehearsed) |
| INF-9.8 | Threat model review; scans gating with a documented exception process |
| INF-9.9 | Cost cleanup automation; first prod promotion (digest-pinned, manual sync) |

**Gate 9:** prod reachable only through authentication; restore drill within RTO ≤ 4 h; first prod promotion done
from a staging-verified digest.

### Phase 10 — Mobile release

| ID | Item |
|---|---|
| INF-10.1 | `mobile-validation.yml` (Android build/test; iOS build/test on macOS) — the `atlas` repo already runs a validation job; align or move |
| INF-10.2 | Protected `release` environment with required reviewer; App Store Connect API key and signing material stored there |
| INF-10.3 | `mobile-release.yml` (manual dispatch, TestFlight/App Store Connect upload, explicit release configuration) |

**Gate 10:** a reviewed manual release reaches TestFlight and the Play internal track.

## 3. Cross-repository hand-offs

| Infra needs / delivers | From / to |
|---|---|
| ADR-0007 accepted (INF-2.0, 2026-11-27) | unblocks `atlas` F2-12; backend BE-2.4 done |
| Shared scanner decision (INF-2.0) | aligns `atlas` F2-11 (Trivy) and backend BE-1.13 |
| GitHub App + bump PRs (INF-2.3) | needs the publishing jobs from `atlas` F2-12 and BE-2.4 |
| `atlas-dev` live (INF-3.7) | first deployed backend + frontend; needs Gate 2 images |
| Staging + e2e (INF-4.2…4.5) | needs backend Gate 3 and BE-4.5; closes `atlas` Gate 9 (F4-6 in staging) |
| Prod identity (INF-9.1) | with backend Phase 9 BFF; lets `atlas` set `auth: true` |

**Critical path:** INF-1.10/1.11 → INF-2.0 (owner ADR review) → INF-2.1…2.3 → owner approval of Phase 3 →
INF-3.1 → INF-3.7 → INF-4.2 → INF-4.5 (staging e2e, shared with backend BE-4.5 and `atlas` F4-6).

## 4. Decisions

Accepted: ADR-0001, ADR-0002 (GitOps, Argo CD, Kustomize, separate repo), ADR-0003 (k3s on one B2as_v2 VM, prod as
a namespace), ADR-0004 (PostgreSQL Flexible Server B1ms, two servers), ADR-0007 (GHCR, image publishing and
promotion; dev bump PRs auto-merge, 2026-11-27), ADR-0009 (Azure services and free tier);
identity provider Microsoft Entra External ID (2026-11-12).

### 4.1 Open decisions to settle before the phase that needs them

| Decision | Recommended default | Needed by |
|---|---|---|
| Shared image scanner | Trivy (Apache-2.0); Grype as fallback | Gate 2 |
| GHCR package visibility | Private until repository visibility is decided; pull Secret via ESO | Gate 2 |
| ADR-0005 secrets | Key Vault + ESO; VM managed identity as fallback to workload identity | Phase 3 |
| ADR-0006 frontend hosting | nginx container behind the same Ingress | Phase 3 |
| Region and domain | Germany West Central; owner-chosen domain with Azure DNS + DNS-01 | Phase 3 |
| Staging access before Phase 9 (backend R-2) | NSG allow-list plus a staging-only Entra app registration for e2e | Phase 4 |
| ADR-0008 migration execution | Start-up Flyway until Phase 9; PreSync Job with a DDL role after | Phase 9 |

## 5. Risks

See PLAN-INFRASTRUCTURE-CICD § Risks for the full list. The ones that drive this order:

- **Cost overrun / forgotten resources:** budget first (INF-3.1), tagging, teardown runbook, cleanup automation in
  Phase 9.
- **Exposure before authentication:** allow-list dev and staging; prod only after Gate 9.
- **Single shared node (accepted, ADR-0003):** non-prod quotas and prod priority in Phase 9; rehearsed rebuild.
- **Staging e2e needs auth (backend R-2):** decide the staging access model before INF-4.5.
- **Free year ends (month 13):** budget raised and reminder at month 12.
