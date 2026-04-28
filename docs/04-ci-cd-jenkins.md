# CI/CD (GitLab + Jenkins + ArgoCD)

Last updated: 2026-03-04

## Current Pipeline Model
1. Developer pushes to `app` repo.
2. GitLab triggers Jenkins.
3. Jenkins pipeline runs on dynamic k8s pod agent.
4. Security gates run before deployment handoff.
5. Images are built/pushed with versioned tags.
6. Images are signed and verified (`main`).
7. GitOps values are updated.
8. ArgoCD syncs desired state to cluster.

## Jenkins Runtime Topology
- Controller: EC2.
- Agents: dynamic Kubernetes pods in EKS (`k8s-agent` namespace).
- Agent containers used in pipeline pod:
  - `python`
  - `kaniko`
  - `gitleaks`
  - `trivy`
  - `cosign`

## Required Jenkins Credentials
- `gitlab-token` for SCM checkout and GitOps push.
- `dockerhub` (`usernamePassword`) for image push and registry auth.
- `slack-token` for notifications.
- Kubernetes cloud credentials for pod provisioning.
- Signing and verification:
  - `cosign-private-key` (`Secret file`)
  - `cosign-public-key` (`Secret file`)
  - `cosign-password` (`Secret text`)
- Vault runtime auth (optional/recommended):
  - `VAULT_ADDR`
  - `VAULT_ROLE_ID`
  - `VAULT_SECRET_ID`
  - optional `VAULT_NAMESPACE`

## Pipeline Stages (`app/Jenkinsfile`)
- EKS connectivity check.
- Full checkout.
- Secret Scan (`gitleaks`).
- Load Runtime Secrets (Vault-first, Jenkins fallback).
- Setup Python venv.
- Pylint quality gate.
- Static analysis (`bandit`, `main` only).
- Dependency Scan (`trivy fs`, `CRITICAL`).
- Dockerfile Scan (`trivy config`, `HIGH,CRITICAL`).
- Build images (Kaniko latest tags).
- Tag images.
- Push release images (Kaniko).
- Sign Container Images (`cosign`, `main` only).
- Verify Container Signatures (`cosign`, `main` only).
- Deploy (GitOps values update/push).

## CI Script Layout
- `scripts/ci/load_runtime_secrets.sh`
- `scripts/ci/build_images_latest.sh`
- `scripts/ci/push_images_release.sh`
- `scripts/ci/sign_images.sh`
- `scripts/ci/verify_signatures.sh`
- `scripts/ci/deploy_gitops.sh`
- `scripts/ci/lib/common.sh`

## Operational Notes
- Keep `cosign` verify stage before deploy stage.
- If workspace cleanup fails due mixed container users, normalize permissions before `deleteDir()`.
- Service account token auth to EKS can expire; refresh Jenkins Kubernetes cloud credential when needed.
