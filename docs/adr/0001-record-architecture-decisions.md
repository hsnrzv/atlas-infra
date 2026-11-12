# ADR-0001: Record architecture decisions

- Status: Accepted
- Date: 2026-11-12
- Deciders: Repository owner (@hsnrzv), platform engineering

## Context

`atlas-infra` captures infrastructure choices with long-lived cost, security and operational consequences:
the Kubernetes platform, database hosting, secret management, promotion flow. Several are still open
(project-instruction §21). Without a written record, the reasons behind a choice, and the alternatives rejected,
get lost, and decisions get re-litigated or silently changed. The sibling repositories use the same practice (see
`atlas` ADR-0001 (record decisions)).

## Decision

Record significant infrastructure decisions as Architecture Decision Records in `docs/adr/`:

- File name `NNNN-kebab-title.md`, numbered from 0001 within this repository; index in `docs/adr/README.md`;
  template in `0000-template.md`.
- Format: `# ADR-NNNN: Title`, `Status`, `Date`, `Deciders`, then Context, Decision, Consequences,
  Alternatives considered, References.
- Status `Accepted` only for decisions made by the owner or baselines implemented in Phase 1; open decisions stay
  `Proposed` with a recommended default until the owner accepts or rejects them.
- ADRs are immutable once accepted, except for status changes; a changed decision gets a new ADR that supersedes the
  old one.
- Cross-repository references name the repository, e.g. "see `atlas` ADR-0002 (repository topology)".
- Facts such as prices and versions carry a source and an access date; unverifiable facts are marked "to verify".

## Consequences

- Every infrastructure PR that makes or changes a significant decision includes or updates an ADR.
- Proposed ADRs make open decisions visible and reviewable before any cloud resource is created.
- Small overhead per decision; mitigated by the template.

## Alternatives considered

- **Decisions only in the plan document.** Rejected: plans change continuously; decisions need a stable, linkable
  record with status.
- **Issues/discussions only.** Rejected: not versioned with the manifests they explain.

## References

- Michael Nygard, "Documenting Architecture Decisions" (2011): https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions
- see `atlas` ADR-0001 (record decisions)
- [Infrastructure & CI/CD plan](../plan/PLAN-INFRASTRUCTURE-CICD.md)
