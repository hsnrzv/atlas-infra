# ADR-0002: GitOps with Argo CD and Kustomize in a separate atlas-infra repository

- Status: Accepted
- Date: 2026-11-12
- Deciders: Repository owner (@hsnrzv), platform engineering

## Context

The specification requires Argo CD for GitOps deployment to Kubernetes (project-instruction §9.5) and recommends a
third repository for GitOps manifests "because GitOps manifests should have an independent lifecycle and review
history" (§0.3). It asks to choose one packaging approach — Kustomize overlays or Helm — and names Kustomize "a
reasonable default for a small application" (§9.5). The repository `atlas-infra` exists alongside `atlas` (frontend)
and `atlas-microservices` (backend) (see `atlas` ADR-0002 (repository topology)).

The application consists of two first-party workloads (backend, frontend) with near-identical configuration across
three environments (`dev`, `staging`, `prod`); differences are namespace, replicas, resources, host name, Spring
profile and image references.

## Decision

1. **Separate repository.** `atlas-infra` owns Kubernetes manifests, Argo CD project/applications, environment
   configuration templates, the local full-stack compose file, infrastructure CI and runbooks. It never owns
   application code or plaintext credentials.
2. **Kustomize is the packaging approach.** Plain-YAML bases in `apps/<component>/base/` and one overlay per
   environment in `environments/<env>/` that sets namespace, replicas, resources, host, Spring profile and pinned
   images (`images:`). No Helm charts are authored for first-party workloads. Third-party platform components
   (Argo CD, External Secrets, cert-manager) may be installed from their upstream Helm charts or manifests at
   bootstrap, pinned to explicit versions.
3. **Argo CD** reconciles each environment from `main` through one `Application` per environment, all in a single
   `AppProject` (`atlas`) that restricts sources to this repository and destinations to the three namespaces.
   `dev` syncs automatically (prune + self-heal); `staging` and `prod` sync manually after a reviewed PR.
4. **Validation in CI** renders every overlay and validates it strictly (kubeconform), enforces the image tag policy
   and rejects committed Secrets (`scripts/validate.sh`, `manifests-ci`).

This is a Phase 1 baseline implemented in this repository; installing Argo CD in a cluster depends on the platform
decision ([ADR-0003](0003-kubernetes-platform.md)).

## Consequences

- Application repos stay free of deployment state; promotions are auditable PRs in one place, with CODEOWNERS on
  `environments/prod/`.
- Image publishing in the application repos must open PRs against this repo (cross-repo token or GitHub App; see
  [ADR-0007](0007-image-publishing-and-promotion.md)).
- Kustomize keeps manifests readable and diffable (`kubectl kustomize environments/<env>`); there is no templating
  language to learn, but there is also no packaging for external consumers (not needed).
- Argo CD itself must be bootstrapped, upgraded and backed up (its configuration is mostly in Git, which reduces
  recovery to re-installing and re-applying `argocd/`).
- Argo CD requires Kubernetes, so non-Kubernetes hosting options (Azure Container Apps, static web hosting) would
  not use this deployment model; any such choice must be recorded in a new ADR (project-instruction §15.2).

## Alternatives considered

- **GitOps directory inside the backend repository.** Allowed by §0.3 if the owner wants two repositories only.
  Rejected: couples deployment review history to backend code and gives the frontend pipeline write access to the
  backend repo.
- **Helm charts for first-party workloads.** Rejected for now: templating adds indirection without a current need
  (no external consumers, few differences between environments). Revisit if configuration permutations grow.
- **Flux CD.** A capable GitOps alternative, but the specification names Argo CD; its UI and sync model fit the manual
  promotion step for staging/prod.
- **Push-based deploys from GitHub Actions (`kubectl apply`).** Rejected: needs cluster credentials in CI and gives no
  continuous drift detection.

## References

- project-instruction.md §0.3, §9.5, §15.4, §16.3 (accessed 2026-11-12)
- Argo CD documentation: https://argo-cd.readthedocs.io/en/latest/ (accessed 2026-11-12; latest release v3.6.1,
  2026-11-04, from https://github.com/argoproj/argo-cd/releases)
- Kustomize: https://kubectl.docs.kubernetes.io/references/kustomize/ (accessed 2026-11-12)
- see `atlas` ADR-0002 (repository topology)
