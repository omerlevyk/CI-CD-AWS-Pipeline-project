# GitOps Repository

This repository is the deployment source of truth consumed by ArgoCD.

## Current Source Configuration
- Repo URL: `https://gitlab.omerlevy03.com/omerlevyk/gitops.git`
- Tracked branch: `main`
- Chart path: `apps/weather-stack/chart`
- Dev values file: `apps/weather-stack/envs/dev-values.yaml`

## Structure
- `apps/weather-stack/chart`: Helm chart templates.
- `apps/weather-stack/envs`: environment values files.
- `argocd/projects`: AppProject manifests.
- `argocd/applications`: ArgoCD Application manifests.
- `argocd/secrets`: repo credential templates (no real secrets in git).

## Deploy ArgoCD Manifests
```bash
kubectl apply -f argocd/projects/apps-project.yaml
kubectl apply -f argocd/applications/weather-stack-dev.yaml
```

## Notes
- Keep real tokens/passwords out of Git.
- App runtime changes should be committed here and synced by ArgoCD.
- Terraform should not own application Helm release state.
