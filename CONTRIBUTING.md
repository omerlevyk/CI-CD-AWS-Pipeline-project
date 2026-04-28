# Contributing Guide

This project uses a GitOps-first workflow across 3 repos:
- `app` for application source and CI pipeline.
- `gitops` for Helm values/manifests consumed by ArgoCD.
- `infra` for Terraform infrastructure.

## Branch Strategy
- `main`: protected, production-facing branch.
- `dev`: integration branch for validated changes.
- Feature branches: branch from `dev`, merge back to `dev` via MR.

Recommended branch names:
- `feat/<short-description>`
- `fix/<short-description>`
- `chore/<short-description>`
- `docs/<short-description>`

## Merge Request Rules
- Use MRs for all changes into `dev` and `main`.
- Keep MRs focused and small when possible.
- Include: what changed, why, and rollback notes.
- Link the related task/checklist document used in the current repo.

## Review Policy
- At least 1 approval before merge.
- Resolve all review comments.
- Do not merge when required checks fail.

## Commit Messages
Use clear scoped commits:
- `feat(scope): ...`
- `fix(scope): ...`
- `chore(scope): ...`
- `docs(scope): ...`

Examples:
- `feat(helm): add startup/readiness/liveness probes`
- `fix(ci): run Jenkins builds on k8s pod agent`

## Signed Commits
- Commits to protected branches should be signed.
- Preferred: SSH signing.
- Alternative: GPG signing.

## GitOps Rules
- App behavior changes: commit in `app`.
- Runtime/deploy config changes: commit in `gitops`.
- Infra changes: commit in `infra`.
- Runtime rollout should flow through Git + ArgoCD sync.

## Deployment Safety Checklist
Before merging deployment-impacting changes:
- Confirm target image tag exists in DockerHub.
- Confirm Helm values are valid for target env.
- Confirm ArgoCD app status after merge (`Synced` and `Healthy`).
