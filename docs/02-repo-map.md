# Repository Map

Last updated: 2026-03-04

## Workspace Layout (`/home/omer/working_dir/devops_project`)
- `app/`: application source, Jenkins pipeline, CI helper scripts.
- `gitops/`: Helm chart/values and ArgoCD manifests.
- `infra/`: Terraform environments/modules and infra scripts.
- `docs/`: architecture, runbooks, and validation evidence.
- `my_notes/`: local planning/checklist notes.

## `app/`
- `Jenkinsfile`: declarative pipeline.
- `scripts/ci/`: reusable CI logic (`load_runtime_secrets`, build/push, sign/verify, deploy).
- `.githooks/pre-commit`: local `gitleaks` hook.
- `python_app/`: Flask service.
- `nginx/`: reverse-proxy image assets.

## `gitops/`
- `apps/weather-stack/chart`: Helm chart templates.
- `apps/weather-stack/envs/dev-values.yaml`: deployment tag source of truth.
- `argocd/projects` and `argocd/applications`: ArgoCD project/app manifests.

## `infra/`
- `envs/dev`: active Terraform environment.
- `modules/`: reusable Terraform modules.
- `scripts/`: helper scripts (`load_infra_env.sh`, startup/shutdown, validation).

## Ownership Model
- App behavior and CI logic: `app/`
- Runtime desired state and promotion gates: `gitops/`
- Cloud/platform resources and cluster base: `infra/`
