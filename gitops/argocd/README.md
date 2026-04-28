# ArgoCD Setup Notes

This folder contains ArgoCD projects, applications, ingress, and secret templates.

## Current Access
- ArgoCD host: `argocd.omerlevy03.com`
- Repo: `https://gitlab.omerlevy03.com/omerlevyk/gitops.git`
- Main app: `weather-stack-dev`

## TLS / Ingress
- Ingress controller: AWS Load Balancer Controller.
- TLS termination: ALB with ACM certificate.
- DNS: Cloudflare CNAME to ALB hostname.

## Repo Credentials
- Use template: `argocd/secrets/repo-credentials-template.yaml`
- Store only templates in git.
- Apply real credentials as Kubernetes secret in `argocd` namespace.
- Recommended runtime bootstrap from Vault:
  - `argocd/scripts/render_repo_credentials_from_vault.sh`

## Platform App Handoff
ALB Controller release ownership moved to ArgoCD app manifest:
- `argocd/applications/aws-load-balancer-controller-dev.yaml`

Terraform side should set:
```hcl
manage_alb_controller_with_terraform = false
```

## Apply Order
1. Apply project manifests.
2. Apply repo credentials secret.
3. Apply application manifests.
4. Verify `Synced` and `Healthy` in ArgoCD.
