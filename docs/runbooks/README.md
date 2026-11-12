# Runbooks

Operational procedures for IKIGAI ATLAS. A runbook is written when the thing it operates exists, and it is rehearsed
before it is relied on: Phase 9 requires a tested restore procedure and documented deployment and rollback (§18).

| Runbook | Status | Phase | Covers |
|---|---|---|---|
| [local-development.md](local-development.md) | available | 1 | full-stack local run, port conflicts, database reset, troubleshooting |
| `cluster-bootstrap.md` | TODO | 3 | budget first; create the resource group, VM and NSG; install pinned k3s, Argo CD, External Secrets Operator and cert-manager; apply the AppProject and Applications; rebuild a lost node (the node is stateless). Rehearsed before prod. |
| `rollback.md` | TODO | 4 | revert a promotion PR and manually sync; when to roll forward instead; checking schema compatibility; drill in staging |
| `promotion.md` | TODO | 4 | promote a tag and digest dev → staging → prod, manual sync, post-sync smoke test |
| `backup-restore.md` | TODO | 9 | PostgreSQL point-in-time restore into a disposable server, logical dump restore from Blob, timing the RTO, quarterly drill log |
| `secret-rotation.md` | TODO | 9 | rotate database and OIDC credentials in Key Vault, ESO refresh, rolling restart, verification |
| `teardown.md` | TODO | 3 | pause (deallocate VM, stop PostgreSQL) and full teardown (`az group delete`), plus checking for leftovers: soft-deleted Key Vaults, disks, IPs, budgets |
| `incident-basics.md` | TODO | 9 | where logs are, health endpoints, Argo CD status, who to contact, how to declare and close an incident |

Runbook conventions:
- purpose and scope;
- prerequisites and access needed;
- exact commands, with placeholders in `<angle brackets>` and never real secrets;
- verification steps;
- rollback or abort steps;
- the date it was last rehearsed.

Related: [PLAN-INFRASTRUCTURE-CICD.md](../plan/PLAN-INFRASTRUCTURE-CICD.md), [ADRs](../adr/README.md).
