# ADR-0003: Kubernetes platform — k3s on an Azure VM vs AKS Free/Standard

- Status: Accepted (2026-11-12, amended: prod runs as a namespace on the same VM; see Decision item 2)
- Date: 2026-11-12
- Deciders: Repository owner (@hsnrzv); platform engineering (recommendation)

## Context

Argo CD is required (project-instruction §9.5), so the application needs a Kubernetes cluster
([ADR-0002](0002-gitops-argocd-kustomize-separate-infra-repo.md)). §15.2 and §21 item 2 ask for an explicit choice
between a cost-first self-managed cluster (k3s on a VM) and managed Kubernetes (AKS), with monthly cost and
operational trade-offs, and forbid presenting an AKS Free cluster as a production availability promise.

Facts (details, sources and retrieval date in [COST-COMPARISON.md](../architecture/COST-COMPARISON.md)):

- Workload: one user, a Spring Boot backend and a static frontend, three environments. A staging environment must
  exist by the end of Phase 4 (end-to-end tests in staging); production follows in Phase 9.
- AKS system node pools need ≥ 4 vCPU / 4 GB VM sizes, no B-series, and at least two nodes (Microsoft Learn,
  accessed 2026-11-12). Smallest priced AKS cluster here: **≈ 313 €/month** (Free tier) or **≈ 378 €/month**
  (Standard tier, 65.55 € management fee), before the database.
- k3s on one Standard_B2as_v2 VM (2 vCPU / 8 GiB) with P6 disk and public IP: **≈ 70 €/month**; on a non-burstable
  Standard_D2as_v5: **≈ 82 €/month**.
- AKS Free has no financially backed SLA and is positioned for dev/test; AKS Standard has a 99.9% (99.95% with
  availability zones) API-server SLA. A single k3s server has no control-plane SLA.
- Region: VM, disk, IP, PostgreSQL and AKS prices are identical in Germany West Central and West Europe.
- The Azure free account's 12-month Linux VMs (B2ats v2 / B2pts v2) have 2 vCPU but only 1 GiB RAM, below the k3s
  server minimum of 2 GB. They cannot host k3s + Argo CD + the JVM, so the cluster VM is paid in every option
  ([ADR-0009](0009-azure-services-and-free-tier.md)).

## Decision

Accepted by the owner on 2026-11-12:

1. **k3s on a single Azure Linux VM** (Standard_B2as_v2, Germany West Central) with Argo CD for `dev` and `staging`
   from Phase 3 (cluster ≈ 70 €/month without free quotas; year-1 and later figures in
   [ADR-0009](0009-azure-services-and-free-tier.md)).
2. **Prod (Phase 9) runs as the `atlas-prod` namespace on the same VM.** The owner explicitly accepted the shared-node
   risk (see Consequences) to save ≈ 82 €/month. Prod data is still isolated on its own PostgreSQL server
   ([ADR-0004](0004-database-hosting.md)) and its own Key Vault ([ADR-0005](0005-secrets-management.md)). The
   previously recommended separate prod VM (Standard_D2as_v5, total ≈ 186 €/month) remains the upgrade path.
3. Nodes are **stateless cattle**: all state lives in Git (manifests), managed PostgreSQL ([ADR-0004](0004-database-hosting.md))
   and Key Vault ([ADR-0005](0005-secrets-management.md)). Recovery is "recreate VM + run the bootstrap runbook",
   which must be tested before prod.
4. Pin the k3s version at bootstrap (stable at 2026-11-12: v1.37.2+k3s1) and use k3s's bundled Traefik ingress and
   embedded NetworkPolicy controller; keep `KUBERNETES_VERSION` in CI aligned with the cluster minor.
5. Exposure: only 80/443 through the NSG. Until authentication exists (Phase 9), dev and staging must not be publicly
   reachable — restrict the NSG source to the owner's IP(s) or use a private tunnel (project-instruction §13.1).
6. Re-evaluate AKS Standard if any of these become true: an uptime SLA is required, more than one operator, sustained
   load beyond one node, or the operational burden becomes the bottleneck.

## Consequences

- Lowest cost that still satisfies the Argo CD requirement; ≈ 4–7× cheaper than the AKS options.
- The owner operates the cluster: OS patching (unattended upgrades + planned reboots), k3s/Argo CD/add-on upgrades,
  monitoring CPU credits on B-series (switch to D2as_v5 for +11.54 €/month if credits run out).
- Single point of failure and maintenance downtime; acceptable for a single-user personal app only if documented.
- **Accepted risk (owner, 2026-11-12): prod shares the node with dev and staging.** Namespaces are organisational
  boundaries, not a complete security boundary (§15.1). A non-prod workload can starve or, after a container escape,
  reach prod. Mitigations:
  - PSA `restricted` and default-deny NetworkPolicies per namespace (in place);
  - a ResourceQuota per non-prod namespace and a higher PriorityClass for prod (Phase 9);
  - separate prod PostgreSQL server, Key Vault and database credentials;
  - manual Argo CD sync for prod.
  Move prod to its own VM (≈ +82 €/month) if any of these become true: the data is shared with other users, non-prod
  runs untrusted or experimental workloads, an uptime target is promised, or memory pressure is measured.
- The Ingress NetworkPolicies select the `kube-system` namespace, where k3s runs Traefik; a different ingress
  controller requires patching those selectors.
- Follow-up: cluster bootstrap runbook (Phase 2), budget alerts before creating the VM, backup of nothing on the node
  (by design) but tested rebuild.

## Alternatives considered

- **AKS Free tier for non-prod + AKS Standard for prod** (≈ 725 €/month incl. two PostgreSQL servers). Managed control
  plane and SLA for prod, but an order of magnitude more expensive than the workload needs.
- **One AKS Standard cluster for all environments** (≈ 412 €/month incl. PostgreSQL). SLA for the API server, still
  ≈ 4× Option 1; environments share nodes anyway.
- **AKS Free tier for everything** (≈ 347 €/month). Rejected: no SLA and explicitly not production-grade (§15.2).
- **Separate prod VM** (Standard_D2as_v5; ≈ 186 €/month for everything, ≈ 149 €/month in year 1 with free quotas).
  Stronger isolation; rejected for now on cost, kept as the upgrade path (see Consequences).
- **Azure Container Apps + Static Web Apps** (≈ 43–65 €/month; ≈ 18–45 €/month with the always-free grants and scale
  to zero). Cheapest to operate, but no Argo CD/GitOps model and JVM cold starts. Re-evaluated with the owner on
  2026-11-12 and rejected: the owner keeps k3s + Argo CD ([ADR-0002](0002-gitops-argocd-kustomize-separate-infra-repo.md)).
- **Azure App Service.** Free F1: 60 CPU minutes per day, 1 GB memory, no custom domain, no Always On, no SLA; not
  viable for production. Basic B1 Linux (≈ 11.83 €/month, 1.75 GB) has no Argo CD path either.
- **Arm64 nodes** (Dpls_v5) to cut AKS cost: requires multi-arch application images; possible later optimisation.

## References

- [COST-COMPARISON.md](../architecture/COST-COMPARISON.md) (Azure Retail Prices API, retrieved 2026-11-12)
- Microsoft Learn, AKS Free/Standard/Premium tiers: https://learn.microsoft.com/en-us/azure/aks/free-standard-pricing-tiers (accessed 2026-11-12)
- Microsoft Learn, AKS system node pools: https://learn.microsoft.com/en-us/azure/aks/use-system-pools (accessed 2026-11-12)
- Microsoft Learn, AKS cost management: https://learn.microsoft.com/en-us/azure/architecture/aws-professional/eks-to-aks/cost-management (accessed 2026-11-12)
- k3s requirements: https://docs.k3s.io/installation/requirements; k3s networking (Traefik, network policy controller): https://docs.k3s.io/networking/networking-services (accessed 2026-11-12)
- project-instruction.md §15.1–§15.3, §21 item 2
