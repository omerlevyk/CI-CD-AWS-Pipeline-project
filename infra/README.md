# Infrastructure Repository (`infra`)

Terraform-based infrastructure for the project platform.

## What This Infrastructure Provisions
- AWS VPC with public/private subnets.
- EKS cluster and managed node group.
- ALB and listener/routing for exposed services.
- GitLab and Jenkins controller EC2 instances.
- IAM/OIDC integration for AWS Load Balancer Controller.
- Cloudflare DNS records for GitLab/Jenkins.

## Current State Summary
- Jenkins controller is on EC2.
- Jenkins build execution is on dynamic k8s pods (not static EC2 agent).
- ArgoCD is installed and used for app deployment (in `gitops` repo).
- Weather app persistence uses EFS (RWX) via Helm values in `gitops`.
- Multi-env layout exists (`envs/dev`, `envs/prov`, `envs/test`) with active implementation in `dev`.

## Directory Layout
- `envs/`: environment entry points (`dev`, `prov`, `test`).
- `modules/`: reusable Terraform modules.
- `../docs/`: project-level architecture, deployment, CI/CD, and runbook docs.
- `kubernetes/`: legacy/sample k8s manifests.

## Quick Start (dev)
```bash
cd /home/omer/working_dir/devops_project/infra/envs/dev
terraform init
terraform plan
terraform apply
```

## Validate
```bash
aws eks update-kubeconfig --region us-east-1 --name weather-app-eks
kubectl get nodes
kubectl get pods -A
kubectl get ingress -A
```

## Important Notes
- Keep secrets out of committed `terraform.tfvars` files.
- Use ArgoCD/GitOps for runtime app deployment changes.
- Keep Terraform focused on infrastructure ownership.

## Security Runbooks
- VPN access control (Tailscale): `../docs/06-vpn-access-tailscale.md`
- Vault secret migration: `../docs/07-vault-secrets-migration.md`
- VPN validation script: `infra/scripts/validate_vpn_access.sh`
- Terraform Vault export helper: `infra/scripts/export_tf_var_cloudflare_from_vault.sh`
