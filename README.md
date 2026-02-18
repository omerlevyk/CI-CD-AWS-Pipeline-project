# GitOps Repo

This repository stores Kubernetes application deployment state for ArgoCD.

## ArgoCD Source Of Truth

Document these values and keep them updated:

- Repo URL: `https://gitlab.omerlevy03.com/omerlevyk/gitops.git`
- Branch: `main`
- Chart path: `apps/weather-stack/chart`
- Values file (dev): `apps/weather-stack/envs/dev-values.yaml`

## Structure

- `apps/weather-stack/chart`: Helm chart for weather + solitaire stack
- `apps/weather-stack/envs/dev-values.yaml`: dev environment values
- `argocd/projects`: ArgoCD AppProject manifests
- `argocd/applications`: ArgoCD Application manifests

## Apply

```bash
kubectl apply -f argocd/projects/apps-project.yaml
kubectl apply -f argocd/applications/weather-stack-dev.yaml
```

## Notes

1. Set `repoURL` in `argocd/applications/weather-stack-dev.yaml`.
2. ArgoCD should own app deployment state from this repo.
3. Terraform in `infra/` should not own app Helm releases.
