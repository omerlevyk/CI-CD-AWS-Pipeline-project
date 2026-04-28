# DevOps Project: AWS EKS + GitLab + Jenkins + ArgoCD

<div align="center">

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)
![Jenkins](https://img.shields.io/badge/jenkins-%232C5263.svg?style=for-the-badge&logo=jenkins&logoColor=white)
![GitLab](https://img.shields.io/badge/gitlab-%23181717.svg?style=for-the-badge&logo=gitlab&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)

</div>

## Project Summary

This repository contains the full DevOps project split into 3 working areas:
- `infra/`: Terraform infrastructure on AWS.
- `app/`: weather application source + Jenkins CI pipeline.
- `gitops/`: Helm chart/values and ArgoCD application manifests.

Current delivery model:
1. Code is built in Jenkins.
2. Images are pushed to DockerHub.
3. Jenkins updates image tags in `gitops` values.
4. ArgoCD syncs the desired state to EKS.

## Current Architecture

- AWS VPC with public/private subnets.
- EKS cluster for workloads.
- Jenkins controller on EC2.
- Jenkins dynamic agents as Kubernetes pods.
- GitLab (self-hosted).
- ArgoCD for GitOps deployment control.
- ALB ingress for external routing.
- EFS-backed persistence for weather app shared history.
- Dynamic pod agents are used instead of a static EC2 Jenkins agent.

## Live Domains (current setup)

- `gitlab.omerlevy03.com`
- `jenkins.omerlevy03.com`
- `argocd.omerlevy03.com`
- `weather.omerlevy03.com`
- `solitaire.omerlevy03.com`

## Repository Layout

```text
.
├── app/          # App source + Jenkinsfile
├── gitops/       # Helm chart, env values, ArgoCD manifests
└── infra/        # Terraform envs/modules/docs
```

## CI/CD and GitOps Flow

1. Developer pushes to `app` repository branches.
2. GitLab triggers Jenkins pipeline.
3. Jenkins runs on EKS dynamic pod agent (`python`, `kaniko`, `gitleaks`, `trivy`, `cosign` containers).
4. Jenkins security gates run before deployment handoff:
   - Secret scan (`gitleaks`)
   - Static analysis (`bandit`, `main` branch)
   - Dependency scan (`trivy fs`, `CRITICAL`)
   - Dockerfile/config scan (`trivy config`, `HIGH,CRITICAL`)
5. Jenkins builds and pushes:
   - `omerlevyk/weather_app-app`
   - `omerlevyk/weather_app-nginx`
6. On `main`, Jenkins signs images (`cosign`) and verifies signatures before deploy.
7. Jenkins updates `gitops/apps/weather-stack/envs/dev-values.yaml` with the new tag and pushes to `gitops` `dev`.
8. `gitops` `dev -> main` merge is used as deployment approval gate.
9. ArgoCD syncs from `gitops` `main`.

## DevSecOps Controls (Current)

- Git secret scanning in CI and pre-commit hook (`gitleaks`)
- Python static analysis (`bandit`) on `main`
- Dependency vulnerability gate (`trivy fs`)
- Dockerfile/config security gate (`trivy config`)
- Container image signing + verification (`cosign`) before deployment


## What Is Already Implemented

- Health probes in Helm values/templates (startup/readiness/liveness).
- Dynamic Jenkins Kubernetes agents.
- ArgoCD app setup and sync flow.
- Branching and signed-commit policy docs.
- Multi-environment Terraform folder structure (`dev/prov/test`) with active `dev` implementation.

## Completed Improvements

- Secure VPN access using Tailscale (implementation complete).
- Secret management migration using HashiCorp Vault (implementation complete).

Implementation runbooks:
- `docs/06-vpn-access-tailscale.md`
- `docs/07-vault-secrets-migration.md`

## Quick Start

### Infrastructure (dev)
```bash
cd /home/omer/working_dir/devops_project/infra/envs/dev
source ../../scripts/load_infra_env.sh
terraform init
terraform apply
```

### Kubernetes access
```bash
aws eks update-kubeconfig --region us-east-1 --name weather-app-eks
kubectl get nodes
```

### ArgoCD app checks
```bash
kubectl get application -n argocd weather-stack-dev
kubectl get ingress -n default
```

## Documentation Index

- Project docs index: `docs/README.md`
- Contribution rules: `CONTRIBUTING.md`
- Infra overview: `infra/README.md`
- Project architecture: `docs/00-architecture.md`
- End-to-end deploy: `docs/03-deploy-end-to-end.md`
- CI/CD details: `docs/04-ci-cd-jenkins.md`
- Operations runbook: `docs/05-operations-runbook.md`

## Credits

Owner:
- Omer Levy

{{- **omerlevyk** - *DevOps Engineer* - [@GitLab Repo](https://git.infinitylabs.co.il/ilrd/ramat-gan/do27/omer.levy)}}
