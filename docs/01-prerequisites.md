# Prerequisites

Last updated: 2026-03-04

## Accounts
- AWS
- DockerHub
- GitLab
- Cloudflare

## Required Local Tools
- Terraform >= 1.5
- AWS CLI
- kubectl
- Helm
- Git
- gitleaks (local pre-commit secret scanning)
- cosign (for local signing/verification tasks)
- Vault CLI (optional, if validating Vault flows locally)

## Required Access
- AWS credentials with permissions to provision VPC/EKS/EC2/IAM/ALB.
- Cloudflare token with DNS edit permission.
- DockerHub credentials for CI image push.
- GitLab access token with repository write permissions for GitOps updates.

## Initial Local Setup
```bash
aws configure
aws sts get-caller-identity
terraform -version
kubectl version --client
```

## Environment Entry Point
Current active environment:
- `infra/envs/dev`

```bash
cd /home/omer/working_dir/devops_project/infra/envs/dev
terraform init
terraform plan
```

## Post-Apply Access
```bash
aws eks update-kubeconfig --region us-east-1 --name weather-app-eks
kubectl get nodes
```

## Security Reminder
Do not store real secrets/tokens in committed plain text files.
Use runtime injection (`Vault`, Jenkins credentials, `.env` ignored files).
