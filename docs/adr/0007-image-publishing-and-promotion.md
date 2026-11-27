# ADR-0007: Image publishing and promotion — GHCR, immutable tags + digests, PR-based promotion

- Status: Accepted (2026-11-27)
- Date: 2026-11-12
- Deciders: Repository owner (@hsnrzv); platform engineering (recommendation)

## Context

- project-instruction §16.2 requires container images to be built, scanned, given an SBOM and provenance where
  practical, published with immutable tags, and deployed by updating `atlas-infra`. §16.4 requires that production is
  never deployed just because a feature branch was merged, and that staging and prod use explicit image versions.
- Image names are fixed by the cross-repo contract: `ghcr.io/hsnrzv/atlas-backend` and `ghcr.io/hsnrzv/atlas-frontend`.
  `latest` must never be used in staging or prod.
- Current state (2026-11-12): `atlas-microservices/.github/workflows/backend-container.yml` and
  `atlas/.github/workflows/frontend-container.yml` build the image on pull requests and pushes to `main` with
  `push: false`. Nothing is published yet, and no workflow has `packages: write`.
- Argo CD deploys whatever `atlas-infra` `main` says ([ADR-0002](0002-gitops-argocd-kustomize-separate-infra-repo.md)).
  The pipeline never needs cluster credentials.
- `scripts/validate.sh` already rejects untagged images and `latest`, and requires digests in prod. The only exception
  is the placeholder `0.0.0-unreleased`, which is used until the first release.

## Decision

Recommended default, awaiting owner approval:

1. **Registry: GitHub Container Registry (GHCR)** with the two contracted image names. Each image is pushed by its
   own repository's `*-container` workflow using `GITHUB_TOKEN` with `packages: write`. That permission is granted
   only to the publishing job, and only on `push` to `main` or a release tag, never on pull requests.
2. **Build once, promote the same digest.**
   - Every push to `main` publishes an immutable tag `main-<12-char git sha>`.
   - A release is created by adding a semantic version tag `X.Y.Z` to an already published digest. This uses
     `docker buildx imagetools create`; the image is **not** rebuilt, so staging and prod run exactly the bytes
     tested in dev.
   - Tags are never moved or overwritten. GHCR does not enforce tag immutability itself (to verify at implementation
     time), so the workflow refuses to push a tag that already exists.
   - `latest` is never pushed.
3. **Supply-chain metadata at publish time:**
   - `docker/build-push-action` with `provenance: mode=max` and `sbom: true`.
   - A container vulnerability scan (Trivy or Grype; the pinned version and the licence check are part of that PR) that
     fails on fixable critical findings.
   - GitHub artifact attestations or cosign keyless signing are an optional follow-up. Admission-time signature
     verification is not planned before Phase 10.
4. **Automated PR to `atlas-infra` for dev.** After a successful publish on `main`, the container workflow opens or
   updates a PR in `atlas-infra` that sets `newTag: main-<sha>` and `digest: sha256:…` for that image in
   `environments/dev/kustomization.yaml`.
   - Credential: a **GitHub App** installation token (`actions/create-github-app-token`) scoped to `atlas-infra` with
     `contents: write` and `pull-requests: write`. A fine-grained personal access token limited to `atlas-infra` is
     the fallback.
   - `manifests-ci` must pass. Auto-merge (squash) is enabled for these dev-only PRs (2026-11-27): the backend
     `bump-infra-dev` job turns it on, and the PR merges once the required checks on `main` are green.
5. **Promotion to staging and prod is a human-reviewed PR.**
   - The PR copies the exact `newTag` + `digest` from the lower environment. Prod requires the digest, which
     `validate.sh` enforces, and CODEOWNERS approval.
   - After merge, an operator triggers a **manual sync** of `atlas-staging` or `atlas-prod` in Argo CD. This is how
     the Applications are already configured.
   - Database migrations must be backward compatible with the previous image
     ([ADR-0008](0008-database-migration-execution.md)).
6. **Rollback** = revert the promotion PR, then manually sync. This only works because migrations follow
   expand/contract. No image is ever deleted while it is referenced by any environment's history in the last 90 days.
7. **Cloud access from CI** (only needed once workflows touch Azure, e.g. infrastructure provisioning) uses
   **GitHub OIDC federation** to a Microsoft Entra workload identity, with no stored cloud secrets. Publishing to GHCR
   and opening PRs need no Azure access.
8. **Package visibility (sub-decision):**
   - If packages stay private, every namespace needs an image pull Secret `ghcr-pull` (type
     `kubernetes.io/dockerconfigjson`), delivered by External Secrets ([ADR-0005](0005-secrets-management.md)), never
     committed.
   - If the owner makes the repositories and packages public, no pull Secret is needed.
   - This is tied to the open LICENSE/visibility decision. Recommended default: private until the owner decides.

## Consequences

- One artefact per commit flows through dev → staging → prod, and every environment is traceable to a Git SHA and
  digest in `atlas-infra` history.
- Dev deploys need no human action beyond merging, or reviewing the bot PR. Staging and prod need two deliberate
  steps: a merged PR, then a manual sync.
- Cross-repo automation needs one extra credential: the GitHub App or fallback token. It must be created by the owner
  and stored as an Actions secret in the two application repositories (not here).
- GHCR storage for private packages may incur cost beyond the plan's included allowance (to verify against the
  owner's GitHub plan). A scheduled clean-up of old `main-*` tags that no environment references keeps this bounded.
- Follow-up work, by repository:
  - In `atlas-microservices` and `atlas`: enable publishing, scanning and SBOM, plus the bump-PR job.
  - In `atlas-infra`: replace the `0.0.0-unreleased` placeholders on the first real release, and add `ghcr-pull`
    ExternalSecrets if packages stay private.

## Alternatives considered

- **Argo CD Image Updater.** It watches the registry and writes tags back to Git or to Application parameters. Not
  chosen: it is another component with registry credentials in the cluster, and the explicit bot PR is easier to
  review and audit.
- **Mutable tags such as `dev` or `staging`** with `imagePullPolicy: Always`. Rejected: they are not reproducible,
  rollback is ambiguous, and they violate §16.4.
- **Rebuilding the image at release time.** Rejected: the released bytes would differ from the tested bytes.
- **Azure Container Registry.** It is a natural fit with AKS managed identity, but it costs money every month, while
  GHCR is integrated with the GitHub repositories at no extra service. Reconsider if the AKS option is chosen
  ([ADR-0003](0003-kubernetes-platform.md)).
- **Push-based deployment from CI (`kubectl apply`).** Rejected by
  [ADR-0002](0002-gitops-argocd-kustomize-separate-infra-repo.md): it needs cluster credentials in CI and has no drift
  detection.

## References

- project-instruction.md §16.2, §16.3, §16.4, §21 items 3 and 11
- Kustomize `images` transformer (`newTag`, `digest`): https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/images/ (accessed 2026-11-12)
- Argo CD sync phases and waves: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/ (accessed 2026-11-12)
- `atlas-microservices` `.github/workflows/backend-container.yml` and `atlas` `.github/workflows/frontend-container.yml` (current build-only state)
- [ADR-0002](0002-gitops-argocd-kustomize-separate-infra-repo.md), [ADR-0005](0005-secrets-management.md), [ADR-0008](0008-database-migration-execution.md)
