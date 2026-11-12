# Security policy

## Reporting a vulnerability

Please **do not open a public issue** for security problems, and never paste secrets, tokens, kubeconfigs, connection
strings or personal data into issues, pull requests or discussions.

Report privately through GitHub's private vulnerability reporting on this repository (**Security → Report a
vulnerability**). If that option is not available, contact the repository owner [@hsnrzv](https://github.com/hsnrzv)
directly through GitHub and ask for a private channel. Include the affected file or environment, the impact, and
reproduction steps.

You will get an acknowledgement as soon as the owner can respond; this is a personal project without a formal
response-time commitment.

## If a secret was committed

1. Treat it as compromised: **rotate it first** (Azure Key Vault / database / GitHub), then remove it.
2. Removing it from the latest commit is not enough; it remains in Git history. Coordinate a history rewrite only if
   needed after rotation.
3. Record the incident and the rotation in the relevant runbook.

## Scope and practices

- This repository must never contain Secrets, credentials, kubeconfigs or decrypted files. `scripts/validate.sh`
  rejects rendered `Secret` objects; `.gitignore` excludes common credential files.
- Local Docker Compose credentials (`atlas`/`atlas`) are throwaway values for a developer machine only and are
  bound to `127.0.0.1`.
- Workloads run under Pod Security Admission `restricted`, as non-root, with read-only root filesystems and default-deny
  network policies.
- CI uses least-privilege `GITHUB_TOKEN` permissions and checksum-verified tool downloads; cloud access (when added)
  will use GitHub OIDC federation instead of long-lived credentials.
- Recommended GitHub settings for this repository: secret scanning with push protection, private vulnerability
  reporting, Dependabot alerts, branch protection on `main` requiring `manifests-ci` and CODEOWNERS review.
