# ADR-0009: Azure services for the production MVP and use of the free tier

- Status: Accepted (2026-11-12)
- Date: 2026-11-12
- Deciders: Repository owner (@hsnrzv); platform engineering (review of the free-service lists)

## Context

The owner supplied Azure's free-service lists as of 2026-11-12: 20 services free for 12 months and 65 services
always free. The question was which services a production-ready MVP needs, and what it needs that the lists do not
cover.

Facts (retrieved or accessed 2026-11-12):

- **Free account terms.**
  - A free account gets a credit for the first 30 days, 12 months of selected services within monthly quotas, and the
    always-free services.
  - When the credit period ends, the subscription is disabled unless it is upgraded to pay-as-you-go. After the
    upgrade, the 12-month services stay free until month 12 ends.
  - Quotas are monthly, do not roll over, and apply only to the listed tiers
    ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/avoid-charges-free-account)).
- **Owner decisions of 2026-11-12:**
  - k3s + Argo CD on **one** Standard_B2as_v2 VM for dev, staging and prod ([ADR-0003](0003-kubernetes-platform.md),
    prod as a namespace);
  - **two** PostgreSQL Flexible Server B1ms servers, non-prod and prod ([ADR-0004](0004-database-hosting.md));
  - **Microsoft Entra External ID** as the identity provider (`atlas-microservices` ADR-0005).
- **The free Linux VMs (B2ats v2, B2pts v2) have 1 GiB RAM.** That is too little for k3s (2 GB minimum) plus Argo CD
  and a JVM.
- **The free PostgreSQL quota (750 h of B1ms + 32 GB storage + 32 GB backup) covers one server for a full month.**
- **Azure AD B2C is still on the always-free list but no longer sold to new customers (since 2025-05-01).**
  - Its successor, Microsoft Entra External ID, is free for the first 50,000 monthly active users. Add-ons such as SMS
    authentication are billed separately.
  - A custom sign-in domain (instead of `<tenant>.ciamlogin.com`) needs a reverse proxy such as Azure Front Door.
  - Self-service sign-up can be disabled per user flow (Graph `isSignUpAllowed: false`).
- **Container images in GHCR currently have free storage and bandwidth.** GitHub promises at least one month's notice
  before that changes.
- **Prices (EUR, Germany West Central, Azure Retail Prices API):**
  - public or private DNS zone 0.4489 per zone-month, plus 0.3591 per million queries;
  - Log Analytics: first 5 GB of Analytics Logs ingestion per month free, then 2.6841 per GB;
  - App Service Linux B1 0.0162 per hour (11.83 per month).
  - Other unit prices are in [COST-COMPARISON.md](../architecture/COST-COMPARISON.md).

## Decision

### 1. Account

- Create the Azure free account **when Phase 3 starts** (the first cloud resource), not earlier, because the 12-month
  clock starts at sign-up.
- Create the budget and anomaly alerts first.
- Upgrade to **pay-as-you-go** before the 30-day credit ends; the VM is not free, so the subscription must not be
  disabled.
- Region: Germany West Central (Proposed default, unchanged).

### 2. Services used from the free lists

| Service (list) | Used for | Phase | Free quota | Billed beyond it |
|---|---|---|---|---|
| Azure Database for PostgreSQL Flexible Server (12 months) | non-prod server `atlas_dev` + `atlas_staging` | 3 | 750 h B1ms, 32 GB storage, 32 GB backup | prod server (Phase 9) and both servers after month 12: 17.00 €/month each |
| Azure Disk Storage (12 months) | Premium SSD P6 OS disk of the k3s VM | 3 | 2 × P6 (one used) | 10.08 €/month after month 12 |
| Azure Key Vault (12 months) | secrets via External Secrets Operator ([ADR-0005](0005-secrets-management.md)): one vault for non-prod, one for prod | 3 / 9 | 10,000 operations | 0.0269 € per 10,000 operations (cents) |
| Azure Blob Storage (12 months) | weekly prod `pg_dump`; OIDC issuer documents if k3s workload identity is used | 9 | 5 GB Hot LRS | Cool tier as planned: < 0.10 €/month for a few GB |
| Bandwidth (always + 12 months) | outbound traffic | 3 | 100 GB + 15 GB per month | not expected |
| Azure Virtual Network (always) | VNet, subnets, NSG (80/443 only), delegated PostgreSQL subnet | 3 | 50 VNets | NSGs are free |
| Microsoft Entra ID (always) | owner admin account, VM managed identity, GitHub OIDC workload identity federation | 3 | free tier | none |
| Microsoft Cost Management (always) | budget, anomaly alerts, free-service usage view | before 3 | free | none |
| Azure Monitor (always, free amounts per feature) | platform metrics and activity log of VM and PostgreSQL, a few metric alerts; optional Log Analytics workspace with a daily cap | 3 | Log Analytics 5 GB per month | metric alerts: cents each per month |
| Microsoft Defender for Cloud (always) | free security posture recommendations (CSPM) | 3 | free tier | Defender plans not enabled |
| Azure Advisor, Azure Policy, Update management center, Resource Manager (always) | recommendations; optional policies (allowed regions, required tags); VM OS patch assessment; Bicep/CLI deployments | 3 | free | none |
| Azure AD B2C (always) | **not usable**: closed to new customers | — | — | replaced by Microsoft Entra External ID (below) |

### 3. Needed but not covered by the free lists

| Item | Why | Phase | EUR (excl. VAT) |
|---|---|---|---|
| Standard_B2as_v2 VM (2 vCPU / 8 GiB) | single k3s node for all environments; the free VMs have 1 GiB | 3 | 56.65 / month |
| Standard static public IPv4 | Ingress endpoint | 3 | 3.29 / month |
| Azure DNS public zone | domain records, cert-manager DNS-01 | 3 | 0.45 / month + queries |
| Azure Private DNS zone | name resolution for PostgreSQL private access (VNet integration) | 3 | 0.45 / month + queries |
| Second PostgreSQL B1ms (prod) | prod data isolated from non-prod | 9 | 17.00 / month |
| Microsoft Entra External ID (external tenant linked to the subscription) | app-user sign-in (OIDC, PKCE) | 4–9 | 0 up to 50,000 MAU; no SMS add-on, no custom sign-in domain in the MVP |
| Domain name | public hostnames | before 9 | external registrar, ≈ 10–15 / year (to verify at purchase) |
| TLS certificates | Let's Encrypt via cert-manager | 3 | free |
| GitHub | repositories, Actions, GHCR, Dependabot | now | GHCR container storage currently free; Actions minutes per GitHub plan |
| Uptime check of prod `/healthz` | alert when prod is down | 9 | Application Insights standard test (billed per run) or a free external monitor; decide in Phase 9 |
| Apple Developer Program, Google Play Console | mobile store release | 10 | ≈ 99 USD / year and ≈ 25 USD once (to verify at enrolment) |
| LLM provider | planning assistant | 11 (post-MVP) | not in the free lists; decided in Phase 11 |

The MVP needs no e-mail service: External ID sends its own verification and one-time-code e-mails. If the
application ever sends e-mail itself, Azure Communication Services Email costs ≈ 0.0002 € per message.

### 4. Not used from the free lists

| Services | Reason |
|---|---|
| AKS | free control plane, but system node pools need ≥ 2 non-B-series nodes with ≥ 4 vCPU: ≈ 313 €/month ([ADR-0003](0003-kubernetes-platform.md)) |
| Container Apps, Static Web Apps, App Service, Functions, Logic Apps, Batch, Service Fabric | no Argo CD deployment path; owner kept k3s + Argo CD on 2026-11-12. App Service F1 is also too limited (60 CPU minutes per day, no custom domain, no SLA). |
| Linux/Windows VMs B2ats v2 / B2pts v2 | 1 GiB RAM |
| Load Balancer | single VM with a public IP; k3s ServiceLB exposes Traefik |
| API Management | Traefik Ingress is the gateway (`/api` → backend, `/` → frontend) |
| VPN Gateway, Private Link | admin access through allow-listed SSH or Run Command; PostgreSQL uses VNet integration, not private endpoints |
| Container Registry | GHCR ([ADR-0007](0007-image-publishing-and-promotion.md)); ACR is billed after month 12 and stays the fallback |
| SQL Database, SQL Managed Instance, MySQL, Cosmos DB, DocumentDB, Files, Archive Storage | PostgreSQL only (project-instruction §9.4) |
| Service Bus, Event Grid, SignalR, Web PubSub, App Configuration, Notification Hubs, IoT Hub, IoT Edge | modular monolith; configuration lives in Git. Notification Hubs may be revisited if push notifications are added after Phase 10. |
| Azure DevOps, DevTest Labs, Deployment Environments | GitHub is the delivery platform |
| AI services (Face, Vision, Custom Vision, Document Intelligence, Speech, Translator, Language, Content Safety, AI Search, Bot Service, Health Bot, Immersive Reader, Machine Learning) | not in the MVP; the Phase 11 provider is decided then |
| Maps, Health Data Services, Data Factory, Data Catalog, Open Datasets, Migrate, Database Migration Service, Resource Mover, Arc, Lighthouse, Managed Applications, Attestation, Automanage, VM Image Builder, Container Storage, Network Watcher, Cloud Shell | not needed. Network Watcher is enabled automatically and is used only for troubleshooting; Cloud Shell is optional for administration. |

### 5. Expected monthly cost

EUR, excluding VAT. Prices are from 2026-11-12.

| Line item | Phases 3–8, year 1 | Phases 3–8, after month 12 | Phase 9+, year 1 | Phase 9+, after month 12 |
|---|---|---|---|---|
| VM Standard_B2as_v2 | 56.65 | 56.65 | 56.65 | 56.65 |
| OS disk P6 | 0.00 | 10.08 | 0.00 | 10.08 |
| Public IPv4 | 3.29 | 3.29 | 3.29 | 3.29 |
| PostgreSQL non-prod | 0.00 | 17.00 | 0.00 | 17.00 |
| PostgreSQL prod | — | — | 17.00 | 17.00 |
| DNS zones (public + private) | 0.90 | 0.90 | 0.90 | 0.90 |
| Key Vault, Blob, bandwidth, Log Analytics, External ID | ≈ 0 | < 0.50 | ≈ 0 | < 0.50 |
| **Total** | **≈ 61** | **≈ 88** | **≈ 78** | **≈ 105** |

Additional one-off and yearly costs: the domain, and the store accounts in Phase 10.

### 6. Guardrails

- **Budget** = expected total + 20%: 75 € in year 1 before Phase 9; 125 € once prod exists or the free year ends.
  Alerts at 50/80/100% actual and 100% forecast, plus anomaly alerts. Set a reminder for month 12.
- **Free-service usage** is reviewed monthly in the portal's free-services view. The PostgreSQL quota is shared, so a
  second B1ms server is never free.
- **Log Analytics:** set a daily cap of 0.15 GB, keep the default retention, and do not ship container logs until
  needed.
- **Key Vault:** ESO `refreshInterval` of 6h ([ADR-0005](0005-secrets-management.md)).

## Consequences

- The production MVP costs ≈ 61 €/month in Phases 3–8 and ≈ 78 €/month with prod in year 1. That rises to ≈ 88 and
  ≈ 105 €/month after the free year. The free quotas save ≈ 27 €/month in year 1.
- The paid VM forces the upgrade to pay-as-you-go within the first 30 days.
- External ID keeps the backend provider-neutral (standard OIDC discovery and JWKS). Sign-in uses
  `<tenant>.ciamlogin.com`; a branded sign-in domain needs Azure Front Door and is out of MVP scope. SMS is not used
  as a factor.
- Re-run the price queries in [COST-COMPARISON.md](../architecture/COST-COMPARISON.md#reproducing-the-prices) and
  re-check the free lists before creating resources.

## Alternatives considered

- **Container Apps + Static Web Apps on the always-free grants** (≈ 18–45 €/month with prod): rejected by the owner to
  keep Argo CD GitOps ([ADR-0003](0003-kubernetes-platform.md)).
- **Separate prod VM** (≈ 149 €/month in year 1, ≈ 186 €/month after): rejected by the owner for cost; it remains the
  upgrade path ([ADR-0003](0003-kubernetes-platform.md)).
- **Pay-as-you-go without a free account:** same services, ≈ 27 €/month more in year 1.
- **Azure AD B2C:** not available to new customers.
- **Self-hosted Keycloak:** more memory on the shared node, plus upgrades and backups for an identity server.

## References

All accessed 2026-11-12.

- Azure free services (lists supplied by the owner): https://azure.microsoft.com/pricing/free-services
- Microsoft Learn, avoid charges with your free account: https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/avoid-charges-free-account
- Microsoft Entra External ID FAQ (B2C end of sale, free tier): https://learn.microsoft.com/en-us/entra/external-id/customers/faq-customers
- Microsoft Entra External ID pricing and add-ons: https://learn.microsoft.com/en-us/entra/external-id/external-identities-pricing
- External ID custom URL domains (Azure Front Door): https://learn.microsoft.com/en-us/entra/external-id/customers/concept-custom-url-domain
- External ID, disable sign-up in a user flow: https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-disable-sign-up-user-flow
- Azure subscription and service limits (App Service tiers): https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits
- GitHub Packages billing: https://docs.github.com/en/billing/concepts/product-billing/github-packages
- Azure Retail Prices API: see [COST-COMPARISON.md](../architecture/COST-COMPARISON.md#reproducing-the-prices)
