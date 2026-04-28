# Project Documentation

Last updated: 2026-03-04

Central documentation for the full project (app + gitops + infra).

## Index
- `00-architecture.md`: high-level architecture.
- `01-prerequisites.md`: prerequisites and tooling.
- `02-repo-map.md`: repository layout and ownership.
- `03-deploy-end-to-end.md`: end-to-end deployment flow.
- `04-ci-cd-jenkins.md`: CI/CD and Jenkins details.
- `05-operations-runbook.md`: operational checks and recovery steps.
- `06-vpn-access-tailscale.md`: VPN access policy and validation.
- `07-vault-secrets-migration.md`: Vault migration and secret handling.
- `templates/`: reusable templates and bootstrap scripts.
- `validation/`: validation logs and evidence checklists.
- `diagrams/`: architecture diagrams and assets.

## Current Delivery Model
- CI: Jenkins dynamic Kubernetes agents.
- Security gates: `gitleaks`, `bandit`, `trivy`.
- Artifact trust: `cosign` sign + verify before deploy.
- CD: GitOps update to `gitops` repo and ArgoCD sync.
