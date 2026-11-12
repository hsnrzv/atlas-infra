# Cost comparison: hosting options for IKIGAI ATLAS on Azure

- Status: input for [ADR-0003](../adr/0003-kubernetes-platform.md) (platform), [ADR-0004](../adr/0004-database-hosting.md)
  (database) and [ADR-0006](../adr/0006-frontend-hosting.md) (frontend hosting) — all Proposed
- Prices retrieved: **2026-11-12** from the public [Azure Retail Prices API](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices)
  (`https://prices.azure.com/api/retail/prices`)
- Regions compared: `germanywestcentral` (Germany West Central) and `westeurope` (West Europe)

## Assumptions

- **Currency EUR, pay-as-you-go** retail prices (`priceType eq 'Consumption'`), Linux, no reservations, no savings
  plans, no Azure Hybrid Benefit, no enterprise/CSP discounts.
- **730 hours per month.** Monthly figures are `unit price × 730` (or the monthly unit price for disks/storage),
  computed from unrounded unit prices and rounded to cents.
- **Excluded unless stated:** VAT, internet egress/bandwidth, DNS zone and domain registration, Log Analytics /
  Azure Monitor ingestion, Microsoft Defender plans, support plans, GitHub costs (GHCR, Actions minutes).
- **Account type is an open decision.** An Azure free account gives a time-limited credit and 12 months of selected
  free services within quotas; usage above the quotas and anything after expiry is charged at pay-as-you-go rates
  ([Microsoft Learn: avoid charges with your free account](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/avoid-charges-free-account),
  accessed 2026-11-12). Which of the services below are covered by free-account quotas is **to verify** on the free
  services page at sign-up time; this comparison assumes none are.
- **Workload size:** one user, two first-party workloads (backend JVM, static frontend), three environments. Memory
  needed for k3s + Argo CD + ingress + External Secrets + cert-manager + the application pods of dev, staging and
  prod on one node is **estimated at ~5.5–6 GiB** from the resource requests in `apps/` and typical controller
  footprints. This is an assumption to validate with `kubectl top` after bootstrap, not a measurement.

## Unit prices (EUR, retrieved 2026-11-12)

Germany West Central and West Europe returned **identical** prices for every VM, disk, IP, load balancer, PostgreSQL
and AKS meter below. They differ only where noted (Container Apps, Static Web Apps).

### Compute (Linux virtual machines)

| Size | vCPU / RAM | Notes | €/hour | €/month |
|---|---|---|---|---|
| Standard_B2als_v2 | 2 / 4 GiB | burstable (CPU credits) | 0.0388 | 28.32 |
| Standard_B2as_v2 | 2 / 8 GiB | burstable (CPU credits) | 0.0776 | 56.65 |
| Standard_B2ms | 2 / 8 GiB | burstable, previous generation | 0.0862 | 62.93 |
| Standard_D2as_v5 | 2 / 8 GiB | non-burstable AMD | 0.0934 | 68.18 |
| Standard_B4als_v2 | 4 / 8 GiB | burstable | 0.1373 | 100.23 |
| Standard_D4pls_v5 | 4 / 8 GiB | Arm64 (needs arm64 images) | 0.1391 | 101.54 |
| Standard_D4als_v6 | 4 / 8 GiB | non-burstable AMD, no local temp disk | 0.1742 | 127.17 |
| Standard_D4as_v5 | 4 / 16 GiB | non-burstable AMD | 0.1867 | 136.29 |

vCPU/RAM from Microsoft Learn size pages ([Basv2](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/basv2-series),
[Dasv5](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dasv5-series),
[Dalsv6](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dalsv6-series), accessed 2026-11-12).

### Storage, network, data, platform fees

| Item | Unit price | €/month |
|---|---|---|
| Premium SSD managed disk P6 (64 GiB) | 10.0785 / month (westeurope 10.0787) | 10.08 |
| Premium SSD managed disk P10 (128 GiB) | 19.4623 / month | 19.46 |
| Standard SSD managed disk E6 (64 GiB) | 4.3090 / month + 0.0018 per 10K transactions | 4.31 + transactions |
| Standard public IPv4 (static) | 0.0045 / hour | 3.29 |
| Standard Load Balancer, first 5 rules (meter region `Global`) | 0.0224 / hour | 16.35 |
| Standard Load Balancer, data processed | 0.0045 / GB | usage |
| PostgreSQL Flexible Server, Burstable **B1ms** compute (1 vCore / 2 GiB) | 0.0179 / hour | 13.07 |
| PostgreSQL Flexible Server, Burstable B2s compute | 0.0715 / hour | 52.20 |
| PostgreSQL Flexible Server storage | 0.1230 / GiB-month (westeurope 0.1229) | 3.94 for the 32 GiB minimum |
| PostgreSQL backup storage (LRS) beyond the free allowance | 0.0925 / GiB-month | 0 within allowance |
| AKS Standard tier ("Uptime SLA" meter) | 0.0898 / cluster-hour | 65.55 |
| Blob storage (General Purpose v2) Hot / Cool / Cold, LRS | 0.0176 / 0.0090 / 0.0040 per GB-month | < 1 for a few GB of dumps |
| Key Vault Standard operations | 0.0269 per 10,000 operations | < 1 at this scale |
| Static Web Apps Standard (only `westeurope` returned a price) | 8.0794 / app-month; first 100 GB bandwidth included, then 0.1795 / GB | 8.08 per app |

Disk prices are LRS disk meters. The API also returns ZRS and separate "Disk Mount" meters; they are not applied here (meaning of "Disk Mount" for a single unshared disk: to verify).

**PostgreSQL B1ms server, minimum configuration (13.07 + 3.94) = 17.00 €/month.** Backup storage is free up to 100% of
provisioned storage, with 7-day default retention (configurable up to 35 days)
([Microsoft Learn: backup and restore in Flexible Server](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-backup-restore),
accessed 2026-11-12).

Two AKS meters were returned but **not applied**: `FreeTierInfrastructureCost Uptime SLA` (0.0449 €/h; purpose
unclear — **to verify**) and the Long-Term-Support meter (0.5386 €/h; LTS is a Premium-tier feature, not needed).

### Azure Container Apps (Consumption plan)

| Meter | germanywestcentral | westeurope |
|---|---|---|
| vCPU active (per second) | USD 0.000024 | USD 0.000034 |
| vCPU idle (per second) | USD 0.000003 | USD 0.000004 |
| Memory active and idle (per GiB-second) | USD 0.000003 | USD 0.000004 |
| Requests (per million) | € 0.3591 (USD 0.40) | € 0.5027 (USD 0.56) |

The API rounds the per-second EUR meters to `0.0000`, so per-second meters are taken in USD (`currencyCode='USD'`)
and converted with the API's own EUR/USD ratio for the Requests meter (0.3591 / 0.40 ≈ **0.8978**, an approximation).
Free monthly grants per subscription: **180,000 vCPU-seconds, 360,000 GiB-seconds and 2 million requests**; the idle
rate applies to replicas kept running by `minReplicas > 0` while idle; apps scaled to zero are not billed
([Microsoft Learn: Container Apps billing](https://learn.microsoft.com/en-us/azure/container-apps/billing), accessed
2026-11-12).

## Options

### Option 1 — k3s on a single Azure VM + Argo CD (cost-first, self-managed)

**Components:** one Linux VM running k3s (bundled Traefik ingress, CoreDNS, local-path storage and an embedded
NetworkPolicy controller), Argo CD, External Secrets Operator, cert-manager; Premium SSD P6 OS disk; one Standard
static public IP; NSG allowing only 80/443 (and SSH/admin from an allow-listed IP, or none via Azure Bastion/Run
Command); managed PostgreSQL (Option 1 assumes ADR-0004's recommendation); Key Vault; Blob for logical backups.

| Line item | B2as_v2 node | D2as_v5 node |
|---|---|---|
| VM | 56.65 | 68.18 |
| OS disk P6 | 10.08 | 10.08 |
| Public IP | 3.29 | 3.29 |
| **Cluster subtotal** | **70.01** | **81.55** |
| + 1 PostgreSQL B1ms (dev + staging databases on one server) | 87.01 | 98.55 |
| + 2nd PostgreSQL B1ms (prod on its own server) | **104.02** | 115.55 |

- **Variant 1b — prod on its own VM** (non-prod B2as_v2 cluster + prod D2as_v5 cluster + 2 PostgreSQL servers):
  **185.56 €/month**. Stronger isolation between prod and non-prod.
- **SLA:** no Kubernetes control-plane SLA (single k3s server). The single-instance VM SLA depends on the disk type
  and is **to verify** in the [Azure SLA document](https://www.microsoft.com/licensing/docs/view/Service-Level-Agreements-SLA-for-Online-Services);
  Microsoft Learn recommends two or more VMs in an availability set for the 99.95% VM SLA
  ([Availability options for Azure VMs](https://learn.microsoft.com/en-us/azure/virtual-machines/availability), accessed 2026-11-12).
- **Ops burden:** high relative to the others — OS patching, k3s upgrades, Argo CD/addon upgrades, node recovery,
  certificate renewal (automated by cert-manager), CPU-credit monitoring on B-series. Mitigation: the node is
  stateless (state in Git, PostgreSQL and Key Vault), so recovery = recreate the VM + bootstrap script.
- **Risks:** single point of failure; maintenance reboots cause downtime; B-series CPU-credit exhaustion under
  sustained load (switch to D2as_v5 for +11.54 €/month); noisy neighbour between environments on one node;
  namespaces are not a full security boundary.
- **Fit:** satisfies the Argo CD requirement at the lowest cost. k3s minimum is 2 cores / 2 GB for a server node
  ([k3s requirements](https://docs.k3s.io/installation/requirements), accessed 2026-11-12); 8 GiB is chosen for headroom.

### Option 2 — AKS: Free tier for non-prod, Standard tier for prod (managed Kubernetes)

**Components:** AKS clusters with a system node pool, managed OS disks, the Standard Load Balancer and public IP AKS
creates, an ingress controller, Argo CD, External Secrets Operator (workload identity), managed PostgreSQL, Key Vault.

Constraints from Microsoft Learn ([system node pools](https://learn.microsoft.com/en-us/azure/aks/use-system-pools),
accessed 2026-11-12): system node pools **require VM sizes with at least 4 vCPUs and 4 GB memory, do not support
B-series VMs, and must contain at least two nodes** (three recommended). Smallest priced fit here: Standard_D4als_v6
(4 vCPU / 8 GiB) at 127.17 + P10 OS disk 19.46 = **146.63 €/node-month** (assumes a managed P10 OS disk because the
size has no local temp disk for an ephemeral OS disk).

| Line item | Free tier (non-prod) | Standard tier (prod) |
|---|---|---|
| Cluster management | 0.00 | 65.55 |
| 2 × D4als_v6 nodes incl. P10 OS disks | 293.26 | 293.26 |
| Standard Load Balancer (≤ 5 rules) | 16.35 | 16.35 |
| Public IP | 3.29 | 3.29 |
| **Cluster subtotal** | **312.89** | **378.45** |

- **Free (non-prod) + Standard (prod) + 2 PostgreSQL B1ms: 725.35 €/month.**
- One Standard cluster for all environments + 2 PostgreSQL B1ms: **412.45 €/month**.
- One Free cluster for all environments + 2 PostgreSQL B1ms: 346.90 €/month — **not production-grade**: Free tier
  has no financially backed SLA and is positioned for development/test.
- Arm64 nodes (D4pls_v5, 121.01 €/node-month with P10) lower the Free-tier cluster to 261.65 €/month but require
  multi-arch (arm64) application images.
- **SLA** ([AKS pricing tiers](https://learn.microsoft.com/en-us/azure/aks/free-standard-pricing-tiers), page updated
  2026-10-20, accessed 2026-11-12): Free — no financially backed uptime SLA, recommended for fewer than 10 nodes
  (dev/test/learning); Standard — financially backed API-server uptime SLA of 99.95% with availability zones, 99.9%
  without. Node VMs are covered by VM SLAs, not the AKS SLA.
- **Ops burden:** medium — Microsoft runs the control plane; node image and Kubernetes version upgrades are
  automatable (auto-upgrade channels). Still need Argo CD, ingress, cert-manager upgrades.
- **Risks:** cost (3.5–7× Option 1); forgotten clusters keep billing (nodes bill even when idle — stop the cluster or
  delete it); Free tier misused as production.

### Option 3 — Azure Container Apps (backend) + Static Web Apps (frontend), no Argo CD

**Components:** one Container Apps environment (Consumption plan) with one backend app per environment, Static Web
Apps for the frontend, managed PostgreSQL, Key Vault references for secrets, deployments from GitHub Actions with
OIDC.

Backend at 0.5 vCPU / 1 GiB, `minReplicas: 1`, full month (2,628,000 s), after free grants (grants applied once per
subscription):

| Scenario | germanywestcentral | westeurope |
|---|---|---|
| prod backend always active | USD 34.02 ≈ **30.54 €** | USD 47.63 ≈ 42.76 € |
| prod backend mostly idle (idle rate) | USD 10.21 ≈ **9.16 €** | USD 13.61 ≈ 12.22 € |
| dev / staging backends scaled to zero | ≈ 0 € (cold starts of a Spring Boot JVM on first request) | ≈ 0 € |

- **Frontend:** Static Web Apps Free plan (no SLA, 2 custom domains, free SSL, 250 MB app size) at 0 €, or Standard
  at 8.08 € per app-month (SLA) ([Static Web Apps plans](https://learn.microsoft.com/en-us/azure/static-web-apps/plans),
  accessed 2026-11-12). Static Web Apps returned a price only for `westeurope`.
- **Total with 2 PostgreSQL B1ms (GWC):** **≈ 43 €/month** (idle prod) to **≈ 65 €/month** (always-active prod),
  plus 8.08–24.24 € if Static Web Apps Standard is used for one to three environments.
- **SLA:** Container Apps SLA **to verify** in the Azure SLA document; Static Web Apps Free has no SLA.
- **Ops burden:** lowest — no cluster, no node patching, no ingress/cert maintenance.
- **Risks / fit:** **does not provide the Argo CD GitOps model** required by project-instruction §9.5/§15.2 — Argo CD
  cannot deploy to Container Apps; deployments would be imperative GitHub Actions steps and drift would not be
  reconciled. The Kubernetes manifests in this repository would not be used. Choosing it requires a new ADR that
  supersedes [ADR-0002](../adr/0002-gitops-argocd-kustomize-separate-infra-repo.md).

## Summary

| | Option 1: k3s on VM | Option 2: AKS Free + Standard | Option 3: Container Apps + SWA |
|---|---|---|---|
| Monthly (all envs, 2 × PostgreSQL B1ms) | **104.02 €** (shared VM) / 185.56 € (separate prod VM) | **725.35 €** (412.45 € single Standard cluster) | **≈ 43–65 €** |
| Monthly, Phases 2–4 (dev + staging only, 1 PostgreSQL) | **87.01 €** | 329.89 € (Free cluster + 1 PG) | ≈ 17–20 € |
| Argo CD GitOps | yes | yes | **no** |
| Control-plane SLA | none | Free: none; Standard: 99.9% / 99.95% | to verify |
| Ops burden | high | medium | low |
| Main risk | single node, self-managed upgrades | cost | no GitOps; JVM cold starts |

**Recommendation (Proposed, see [ADR-0003](../adr/0003-kubernetes-platform.md)):** Option 1 — k3s on one
Standard_B2as_v2 VM for dev + staging from Phase 2–4, with prod added in Phase 9 either on a separate D2as_v5 VM
(recommended for isolation, total ≈ 186 €/month) or, if the owner accepts the documented risk, as a namespace on the
same VM (≈ 104 €/month). Revisit AKS Standard if an SLA becomes a requirement.

**Region (open decision):** VM, disk, IP, load-balancer, PostgreSQL and AKS prices are identical in Germany West
Central and West Europe. Germany West Central is cheaper for Container Apps; Static Web Apps prices were only returned
for West Europe. **Recommended default: Germany West Central** (no price disadvantage for the recommended option; keep
all resources in one region). Choose West Europe if Static Web Apps or a service missing in Germany West Central
becomes necessary — verify service availability in the region before creating resources.

## Budget alerts and teardown (before any resource is created)

1. Create the subscription-level **budget** first (Cost Management → Budgets): monthly amount = chosen option's
   estimate + 20%; alerts at 50%, 80%, 100% actual and 100% forecast, sent to the owner's e-mail.
2. Enable **cost anomaly alerts** for the subscription.
3. Put every resource in one resource group per environment group (e.g. `rg-atlas-nonprod`, `rg-atlas-prod`) and tag
   it `project=ikigai-atlas`, `environment=<env>`, `owner=hsnrzv`, so cost is attributable and teardown is one
   operation.
4. **Teardown:** `az group delete --name rg-atlas-nonprod` removes everything in the group. Check afterwards for
   resources outside the group (public IPs, disks, Key Vault in soft-deleted state, PostgreSQL long-term backups,
   AKS node resource group `MC_*` if AKS was used) and for active budgets. Key Vault soft-delete retains the vault
   name; purge only if protection settings allow and you are sure.
5. To pause non-prod cheaply: stop (deallocate) the VM — compute stops billing; disks and the static IP keep billing.
   A stopped PostgreSQL Flexible Server stops compute billing but "remains stopped for seven days unless you restart
   it sooner" ([Microsoft Learn: Flexible Server overview](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/overview),
   accessed 2026-11-12); storage keeps billing.

## Reproducing the prices

All queries use `GET https://prices.azure.com/api/retail/prices?currencyCode='EUR'&$filter=<filter>` (use `'USD'` for
the Container Apps per-second meters). Replace `<region>` with `germanywestcentral` or `westeurope`.

| Item | `$filter` |
|---|---|
| VM sizes | `armRegionName eq '<region>' and serviceName eq 'Virtual Machines' and armSkuName eq 'Standard_B2as_v2' and priceType eq 'Consumption'` (repeat per size; ignore rows whose product/meter contains Windows, Spot, Low Priority or Cloud Services) |
| Managed disks | `armRegionName eq '<region>' and serviceName eq 'Storage' and contains(productName,'Premium SSD Managed Disks')` (and `'Standard SSD Managed Disks'`) |
| Public IP | `armRegionName eq '<region>' and productName eq 'IP Addresses'` |
| Load Balancer | `serviceName eq 'Load Balancer' and armRegionName eq 'Global'` |
| PostgreSQL Flexible Server | `armRegionName eq '<region>' and serviceName eq 'Azure Database for PostgreSQL' and priceType eq 'Consumption'` (filter `B1MS`, storage, backup rows) |
| AKS | `armRegionName eq '<region>' and serviceName eq 'Azure Kubernetes Service'` |
| Container Apps | `armRegionName eq '<region>' and serviceName eq 'Azure Container Apps'` |
| Blob storage | `armRegionName eq '<region>' and productName eq 'General Block Blob v2'` |
| Static Web Apps | `armRegionName eq '<region>' and contains(productName,'Static Web')` |
| Key Vault | `armRegionName eq '<region>' and serviceName eq 'Key Vault'` |

Example:

```bash
curl -sG "https://prices.azure.com/api/retail/prices" \
  --data-urlencode "currencyCode=EUR" \
  --data-urlencode "\$filter=armRegionName eq 'germanywestcentral' and serviceName eq 'Virtual Machines' and armSkuName eq 'Standard_B2as_v2' and priceType eq 'Consumption'" \
  | jq -r '.Items[] | [.productName, .meterName, .retailPrice, .unitOfMeasure] | @tsv'
```

Prices change; re-run the queries and update this document (with the new retrieval date) before creating resources.
