# Contributing to atlas-infra

This repository is the single source of truth for what runs in every IKIGAI ATLAS environment. Treat every change
as a deployment change.

## Workflow

- **Trunk-based development.** `main` is always deployable to `dev`. Work on short-lived branches and merge via pull
  request within a day or two:
  - `feat/…` new infrastructure capability (e.g. `feat/external-secrets`)
  - `fix/…` corrections (e.g. `fix/backend-probe-timeout`)
  - `docs/…` documentation, runbooks, ADRs
  - `chore/…` tooling, dependency bumps, image promotions (e.g. `chore/promote-backend-1.4.0-staging`)
- **Conventional Commits** for commit messages and PR titles, e.g. `feat(argocd): add atlas-staging application`,
  `chore(prod): promote atlas-backend 1.4.0`, `docs(adr): propose k3s platform`.
- No direct pushes to `main`; branch protection requires the `manifests-ci` check and a CODEOWNERS review.

## Promotion rules

| Environment | How a change arrives | How it is applied |
|---|---|---|
| `dev` | PR merged to `main` (including automated image-bump PRs from the backend/frontend container workflows) | Argo CD **automated** sync with prune and self-heal |
| `staging` | reviewed PR that copies the tag **and digest** already verified in `dev` into `environments/staging` | **manual** Argo CD sync by an operator |
| `prod` | reviewed PR (CODEOWNERS) that copies the tag and digest verified in `staging` into `environments/prod`; digest pinning is mandatory | **manual** Argo CD sync by an operator, after a final check |

- Promote the *same* image (identical digest) from environment to environment; never rebuild for a later stage.
- One environment per promotion PR, so each step is reviewable and revertible on its own.
- Rollback = revert the promotion PR (or open a PR pinning the previous tag + digest), then sync. Database migrations
  must be backward compatible across the deployment window (expand/contract; see
  [ADR-0008](docs/adr/0008-database-migration-execution.md)), so the previous version keeps working.
- Never use `latest` or any mutable tag; `scripts/validate.sh` rejects it.

## Local checks before opening a PR

```bash
scripts/validate.sh                              # renders all overlays + image policy (+ kubeconform if installed)
docker compose -f local/compose.yaml config -q   # if local/ changed
```

CI additionally runs kubeconform (required), shellcheck and yamllint with pinned versions.

## Definition of Done (PR checklist)

The pull request template contains the checklist. A change is done when:

1. Scope is clear and the linked plan item or issue is referenced.
2. `manifests-ci` is green (render, image policy, schema validation, lint).
3. No secrets, kubeconfigs, tokens or decrypted files are added; secrets come from the secret store
   (see "Secrets contract" in the [README](README.md#secrets-contract)).
4. Security implications are considered: securityContext, NetworkPolicy, RBAC/AppProject scope, public exposure.
5. Deployment and rollback implications are described in the PR (including database migration compatibility).
6. Documentation, runbooks and ADRs are updated where behaviour or a decision changed.
7. New resource kinds are added to the Argo CD AppProject whitelist in the same PR.

## Architecture decisions

Significant or hard-to-reverse choices get an ADR in [`docs/adr/`](docs/adr/README.md) using
[`0000-template.md`](docs/adr/0000-template.md). Open decisions stay `Proposed` until the owner accepts them.
