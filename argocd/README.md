# ArgoCD Access Prerequisites (Job 8)

This file defines the required access settings before ArgoCD installation/exposure.

## 1) ArgoCD Hostname

- Hostname: `argocd.omerlevy03.com`

## 2) TLS / Certificate Plan

- Ingress controller: AWS Load Balancer Controller (ALB)
- TLS termination: ALB HTTPS listener (port 443)
- ACM certificate ARN: `arn:aws:acm:us-east-1:960828421635:certificate/354e07ad-76e2-4921-a459-85fe48702d1f`
- DNS provider: Cloudflare
- DNS record plan:
  - `argocd.omerlevy03.com` -> CNAME -> ArgoCD ALB hostname
  - prefer `DNS only` while validating connectivity

## 3) SCM Credentials ArgoCD Will Use

- Git provider: self-hosted GitLab (`gitlab.omerlevy03.com`)
- Deployment repo: `https://gitlab.omerlevy03.com/omerlevyk/gitops.git`
- Access mode: HTTPS with a dedicated read-only token user (recommended)
- Kubernetes secret template: `argocd/secrets/repo-credentials-template.yaml`

## Implementation Notes

- Keep ArgoCD repo credentials read-only.
- Do not commit real token values to git.
- After ArgoCD install:
  1. Apply repo credentials secret in `argocd` namespace.
  2. Apply ArgoCD project/app manifests.
  3. Validate sync from `main` branch.

## Platform Controller Migration (ALB Controller -> ArgoCD)

New manifests:
- `argocd/projects/platform-project.yaml`
- `argocd/applications/aws-load-balancer-controller-dev.yaml`

Safe handoff order:
1. Apply platform project and ALB controller application manifests.
2. Confirm ArgoCD app is `Synced` and `Healthy`.
3. In Terraform (`infra/envs/dev/terraform.tfvars`) set:
   - `manage_alb_controller_with_terraform = false`
4. Run Terraform apply once to stop Terraform ownership of the Helm release.
5. Keep IRSA role + service account in Terraform (only Helm release ownership moves to ArgoCD).
