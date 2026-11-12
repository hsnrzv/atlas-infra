## Summary

<!-- What changes and why. Link the issue / plan item (docs/plan/PLAN-INFRASTRUCTURE-CICD.md). -->

## Type of change

- [ ] Image promotion (tag/digest bump) — environment: `dev` / `staging` / `prod`
- [ ] Manifest / overlay change
- [ ] Argo CD project / application change
- [ ] Local stack (`local/`)
- [ ] CI / scripts / policies
- [ ] Documentation / ADR

## Promotion checklist (image bumps only)

- [ ] Image reference is an immutable version tag (never `latest`); prod also pins `@sha256:` digest
- [ ] The same tag + digest was deployed and verified in the previous environment (dev → staging → prod)
- [ ] Database migrations in this release are backward-compatible (expand/contract, see ADR-0008)
- [ ] Rollback target (previous tag + digest) noted below

Rollback target:

## Definition of Done

- [ ] `scripts/validate.sh` passes locally (renders all overlays, image policy, kubeconform)
- [ ] `docker compose -f local/compose.yaml config -q` passes (if `local/` changed)
- [ ] No secrets, kubeconfigs, or decrypted files added
- [ ] Security implications considered (RBAC, NetworkPolicy, securityContext, exposure)
- [ ] Deployment/rollback implications described
- [ ] Docs, runbooks, or ADRs updated where behaviour or decisions changed
- [ ] Nothing is synced to `staging`/`prod` until this PR is approved and merged; then sync manually in Argo CD
