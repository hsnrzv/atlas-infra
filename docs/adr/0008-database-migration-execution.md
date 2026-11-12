# ADR-0008: Database migration execution strategy

- Status: Proposed
- Date: 2026-11-12
- Deciders: Repository owner (@hsnrzv) — decision pending; platform engineering and backend (recommendation)

## Context

- The backend runs **Flyway on application startup**. `atlas-microservices/src/main/resources/application.yaml`, as
  of 2026-11-12, sets `spring.flyway.enabled: true`, schema `atlas`, `create-schemas: true` and `locations:
  classpath:db/migration`, plus `spring.jpa.hibernate.ddl-auto: validate`. The only migration so far is
  `V1__baseline.sql`.
- Verified locally on 2026-11-12 with `local/compose.yaml`:
  - The backend container (profile `dev`, non-root UID 10001) created schema `atlas` and applied `V1` before
    reporting ready.
  - It ran unchanged with a read-only root filesystem, all capabilities dropped and only `/tmp` writable.
- The backend Deployment uses `RollingUpdate` with `maxSurge: 1, maxUnavailable: 0`: the new pod starts, and
  therefore migrates, while the old pod still serves traffic.
  - Prod runs two replicas.
  - The startup probe allows up to 150 s (`failureThreshold: 30` × `periodSeconds: 5`) for JVM start plus migrations.
- project-instruction §16.4 requires backward-compatible, expand/contract migrations and that the migration order is
  documented. §15.5 requires a strategy for database migrations, and §17.4 asks for rollback and migration
  compatibility tests.
- Argo CD supports `PreSync` hook Jobs and sync waves.
  - Its documentation warns that a PreSync hook runs before the Application's own Secrets are applied.
  - It also warns that hooks run on every sync, that the sync operation stays open while the hook runs, and that
    Argo CD only sees the Job's exit code.
  - Source: [Sync Phases and Waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/), accessed
    2026-11-12.

## Decision

Recommended default, awaiting owner approval:

1. **All environments, always: expand/contract.**
   - Every migration must be compatible with the currently deployed application version (N−1) **and** the new one
     (N). Destructive steps (drop or rename a column, add `NOT NULL` without a default, tighten a constraint) are
     split across at least two releases: expand → migrate data and switch reads/writes → contract.
   - Migrations are forward-only. Rollback means redeploying the previous image, which must still work against the
     expanded schema. Flyway undo is not used.
   - Long-running data back-fills do not run in Flyway; they get a separate, idempotent job.
2. **Phases 1–4 (local, dev, staging): keep Flyway on application startup** (the current behaviour).
   - It is simple and needs no extra manifests.
   - Concurrent replicas are safe because Flyway serialises `migrate` with a PostgreSQL advisory lock. Evidence:
     `PostgreSQLAdvisoryLockTemplate` in `flyway-database-postgresql` 12.4.0, the version in the local Maven cache
     on 2026-11-12.
   - The 150 s startup budget is adequate for the small schema expected in these phases.
3. **Before the first production deployment (Phase 9), switch staging and prod to an Argo CD `PreSync` hook Job.**
   Staging changes first so the mechanism is tested before prod.
   - The Job runs the **same backend image and digest** as the Deployment in a migrate-only mode, then exits.
   - Hook annotations: `argocd.argoproj.io/hook: PreSync` and
     `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation`. Failed Jobs are kept for diagnosis until the next
     sync.
   - Job settings: `backoffLimit: 0`, an `activeDeadlineSeconds` below the Argo CD sync timeout, and the same
     restricted `securityContext` as the Deployment.
   - The Job connects with a **separate DDL-owning database role** from Secret `atlas-backend-db-migrator`. The
     application uses a DML-only role with `SPRING_FLYWAY_ENABLED=false`, so a compromised app pod cannot alter the
     schema.
   - Because PreSync runs before the Application's own resources, the `ExternalSecret` objects for both roles live in
     a separate per-environment Argo CD Application (`atlas-<env>-secrets`) that is synced first. Hook credentials
     then exist before the hook runs, which follows the Argo CD guidance above.
   - If the Job fails, the sync stops before any Deployment changes, so the old version keeps running against an
     unchanged schema.
   - When this lands, the AppProject whitelist gains `batch/Job`.
4. **Dev keeps startup migration** even after step 3: it is the integration environment for each `main` commit and
   benefits from the shortest path.
5. **Ordering** for a release that contains migrations:
   1. Expand migration and code that tolerates both schemas are released together.
   2. Promotion to staging runs the migration (step 3) before the rolling update.
   3. Prod follows with the same digest.
   4. The contract migration ships in a later release, only after no deployed version uses the old shape.

## Consequences

- Cross-repo dependency: `atlas-microservices` must provide a **migrate-only mode** before Phase 9. For example, a
  `migrate` Spring profile that runs Flyway with `spring.main.web-application-type=none` and exits 0, with a test.
  It must also provide the two-role database setup (DDL owner versus application role) in its database plan.
- Startup migration (dev) keeps a risk: a slow migration can exceed the 150 s startup budget and get the pod killed
  mid-migration. PostgreSQL transactional DDL limits the damage, but long migrations must not be written as Flyway
  scripts (rule 1).
- The PreSync Job runs on every sync, including no-op syncs. Flyway with nothing to apply is idempotent, so this only
  costs a short Job run.
- A backup or restore point must be confirmed before prod syncs that contain migrations. PostgreSQL Flexible Server
  point-in-time restore gives this without a manual step ([ADR-0004](0004-database-hosting.md)).
- CI follow-ups belong to backend CI:
  - migration tests against an empty database and against the previous release's schema;
  - an "N−1 app against N schema" compatibility test before Phase 9 (§17.4).

## Alternatives considered

- **Startup migration everywhere, permanently.**
  - Simplest, and correct as long as expand/contract is respected.
  - Rejected for prod because the app's runtime credentials need DDL rights, and a failed migration becomes a crash
    loop of new pods rather than a clean, visible sync failure before rollout.
- **Init container in the backend pod running the migration.**
  - Runs once per pod, so it repeats with every replica and every restart.
  - Shares the pod's credentials, which defeats the role separation.
  - Rejected.
- **Separate Flyway CLI image built from the migration scripts.**
  - Decouples the migration runtime from the app, but adds a third image to build, scan and promote.
  - The schema and the app could also drift.
  - Rejected in favour of reusing the app image.
- **Migrations run from CI against the database.** Rejected: CI would need network access and credentials for the
  production database, which breaks the pull-based GitOps model
  ([ADR-0002](0002-gitops-argocd-kustomize-separate-infra-repo.md)).

## References

- project-instruction.md §15.5, §16.4, §17.4
- Argo CD sync phases, waves and hooks: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/ (accessed 2026-11-12)
- `atlas-microservices` `src/main/resources/application.yaml` and `src/main/resources/db/migration/V1__baseline.sql` (state on 2026-11-12)
- [ADR-0004](0004-database-hosting.md) (database hosting), [ADR-0005](0005-secrets-management.md) (secrets), [ADR-0007](0007-image-publishing-and-promotion.md) (promotion)
