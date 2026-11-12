# ADR-0005: Production secrets — External Secrets Operator + Azure Key Vault (workload identity)

- Status: Proposed
- Date: 2026-11-12
- Deciders: Repository owner (@hsnrzv) — decision pending; platform engineering (recommendation)

## Context

Secrets must never be stored in Git (project-instruction §13.2, §0.3) and production secrets need a protected solution
(§21 item 10). The manifests already reference a Secret that is not committed: `atlas-backend-db` with keys
`SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`, plus the TLS Secret `atlas-tls`.
Later phases add OIDC client configuration (Phase 9). `scripts/validate.sh` fails if any rendered manifest contains a
`Secret`.

Argo CD syncs from Git, so whatever is in Git must be safe to publish; the secret values have to come from somewhere
else and be rotated without a code change.

## Decision

Recommended default (awaiting owner approval):

1. **Azure Key Vault (Standard)** is the source of truth for secret values — one vault per environment group
   (`kv-atlas-nonprod`, `kv-atlas-prod`), RBAC authorisation, soft-delete and purge protection on prod.
2. **External Secrets Operator** (ESO; latest release v2.15.0 on 2026-11-10, Apache-2.0) runs in the cluster. Each
environment gets a `SecretStore` (provider `azurekv`) and `ExternalSecret` objects that materialise
`atlas-backend-db` (and later OIDC and migration secrets) in the environment namespace with a refresh interval.
They are synced by a small separate Argo CD Application per environment (`atlas-<env>-secrets`) before the main
Application, so that `PreSync` hooks such as the migration Job ([ADR-0008](0008-database-migration-execution.md))
find their credentials.
3. **Authentication to Key Vault:**
   - Preferred: **Azure workload identity** — ESO's service account federated with a user-assigned managed identity
     that has `Key Vault Secrets User` on exactly one vault. On k3s this requires publishing the cluster's service
     account OIDC issuer (discovery document + JWKS) at a public URL, as described for self-managed clusters.
   - Acceptable fallback on a k3s VM: ESO authType `ManagedIdentity` using the VM's user-assigned identity via the
     instance metadata endpoint; application pods must not reach the metadata endpoint (the backend's egress policy
     only allows DNS and PostgreSQL; the frontend has no egress).
4. The AppProject whitelist gains `external-secrets.io` `SecretStore`/`ExternalSecret` in the same PR that adds them.
5. No Kubernetes Secret values are ever committed, encrypted or not.

## Consequences

- Rotation = update the value in Key Vault; ESO refreshes the Secret; restart the backend (or add a reloader later).
- Key Vault cost at this scale is below 1 €/month (0.0269 € per 10,000 operations, retrieved 2026-11-12). A free
  account adds 10,000 free operations per month for 12 months ([ADR-0009](0009-azure-services-and-free-tier.md)).
  ESO reads each referenced key once per refresh: about 730 reads per key per month at `refreshInterval: 1h`. Use
  `6h` unless faster rotation is needed; either way the cost stays in cents.
- The cluster needs ESO installed and upgraded (pinned version at bootstrap).
- Until this is implemented, backend pods in a cluster stay pending on the missing Secret — intentionally there is no
  fallback to committed credentials.
- CI never needs secret values; GitHub Actions uses OIDC federation for any Azure access ([ADR-0007](0007-image-publishing-and-promotion.md)).

## Alternatives considered

- **SOPS-encrypted Secrets in Git** (SOPS v3.13.3, MPL-2.0) with Argo CD decryption (plugin or KSOPS). Works offline
  and is cheap, but ciphertext lives forever in Git history, key management moves to the cluster/CI, and Argo CD
  needs a custom plugin. Rotation requires a commit.
- **Sealed Secrets** (v0.41.2, Apache-2.0). Simple and Git-native, but secrets are bound to the controller key;
  losing the key (e.g. rebuilding the stateless node) means re-sealing everything unless the key is backed up —
  conflicts with the "node is cattle" principle in [ADR-0003](0003-kubernetes-platform.md).
- **Manually created Kubernetes Secrets** (`kubectl create secret`). No audit trail, no rotation story, lost on rebuild.
- **Secrets Store CSI Driver with the Azure provider.** Mounts secrets as files; Spring needs env vars or config
  trees and the CSI driver needs a pod volume per consumer. Viable, but ESO fits the existing env-var contract better.

## References

- External Secrets Operator, Azure Key Vault provider: https://external-secrets.io/latest/provider/azure-key-vault/ (accessed 2026-11-12)
- Azure AD Workload Identity, self-managed clusters: https://azure.github.io/azure-workload-identity/docs/installation/self-managed-clusters.html (accessed 2026-11-12)
- Release data from GitHub releases of external-secrets/external-secrets, getsops/sops, bitnami-labs/sealed-secrets (accessed 2026-11-12)
- project-instruction.md §13.2, §16.3, §21 item 10
