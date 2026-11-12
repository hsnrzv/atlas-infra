# ADR-0004: Database hosting — Azure Database for PostgreSQL Flexible Server vs self-hosted PostgreSQL

- Status: Accepted (2026-11-12)
- Date: 2026-11-12
- Deciders: Repository owner (@hsnrzv); platform engineering (recommendation)

## Context

The application stores sensitive personal, financial and health-related data (project-instruction §13) in
PostgreSQL 18 (§9.4). §9.5 and §15.3 prefer a managed database for durable production data "when affordable"; a
self-hosted database is acceptable only with a deliberately designed and tested backup/restore plan (§13.3). §21
item 3 asks for an explicit decision. The backend uses one database `atlas` with schema `atlas`, migrated by Flyway
(see `atlas-microservices` plans).

Facts (retrieved 2026-11-12, see [COST-COMPARISON.md](../architecture/COST-COMPARISON.md)):

- Flexible Server Burstable **B1ms** (1 vCore / 2 GiB): 13.07 €/month compute + 3.94 €/month for the 32 GiB minimum
  storage = **17.00 €/month** per server, identical in Germany West Central and West Europe. PostgreSQL 18 is offered.
- Automated backups are included: default retention 7 days, configurable up to 35 days; backup storage is free up to
  100% of provisioned storage; backups are encrypted (AES-256) and stored on zone-redundant storage in the region;
  point-in-time restore within the retention window.
- Microsoft positions Burstable for "low-cost development and low concurrency workloads without continuous compute
  capacity". A single-user application is a low-concurrency workload.
- A stopped server stays stopped for at most seven days, then starts automatically.
- The Azure free account includes, for 12 months, 750 hours per month of Flexible Server Burstable B1ms with 32 GB
  storage and 32 GB backup storage. That covers **one** server running all month; a second server is billed
  ([ADR-0009](0009-azure-services-and-free-tier.md)).

## Decision

Accepted by the owner on 2026-11-12 (two servers, prod isolated):

1. **Azure Database for PostgreSQL Flexible Server, PostgreSQL 18, Burstable B1ms, 32 GiB**, in the same region as the
   cluster, **not publicly accessible** (private access/VNet integration or, at minimum, firewall rules limited to the
   cluster's egress IP; TLS required).
2. **Two servers:** one for non-prod (separate databases `atlas_dev` and `atlas_staging`, separate logins) from Phase
   2–4, one for prod from Phase 9. Prod backup retention 35 days; non-prod 7 days.
3. **No `apps/postgres/` in this repository.** Kubernetes connects through the `atlas-backend-db` Secret
   (`SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`).
4. Application role is not the owner/DDL role once the migration Job exists ([ADR-0008](0008-database-migration-execution.md)).
5. Add a weekly encrypted logical backup (`pg_dump`) to Blob Storage (Cool tier, separate storage account, lifecycle
   policy) for prod — independent of the service's PITR, as §13.3 suggests "if affordable" (< 1 €/month at this size).

## Consequences

- Durable data with built-in PITR for 17 €/month per server. In the first 12 months of a free account the non-prod
  server is covered by the free quota, so only the prod server (from Phase 9) is billed; no database operations on the k3s node, which keeps the
  node stateless ([ADR-0003](0003-kubernetes-platform.md)).
- Burstable CPU credits can run out under sustained load; monitor and scale to a larger SKU if needed (B2s is
  52.20 €/month compute).
- High availability is not configured (cost); the PostgreSQL SLA without HA applies. RPO/RTO proposal: see the plan's
  backup section.
- Major version upgrades are a managed operation, but still need a tested procedure.
- Restore must be tested into a clean environment before backups are called "done" (§13.3).

## Alternatives considered

- **Self-hosted PostgreSQL in k3s** (StatefulSet + local-path PV, or the CloudNativePG operator). Saves ≈ 17 €/month
  per server but puts the most valuable data on a single VM disk, requires our own WAL archiving/backups to Blob,
  restore drills, upgrades and monitoring, and makes the node stateful. Acceptable only for dev, if at all.
- **PostgreSQL on a separate VM.** Same operational burden as above, no cost advantage over B1ms.
- **One server for all environments.** Cheapest (17 €/month), but prod data shares a server, credentials boundary
  and maintenance window with non-prod; not recommended once prod exists.

## References

- Microsoft Learn, Flexible Server overview: https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/overview (accessed 2026-11-12)
- Microsoft Learn, backup and restore: https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-backup-restore (accessed 2026-11-12)
- [COST-COMPARISON.md](../architecture/COST-COMPARISON.md)
- project-instruction.md §9.4, §9.5, §13.2, §13.3, §21 item 3
- `atlas-microservices` `docs/plan/PLAN-DATABASE.md` (schema and migration conventions)
