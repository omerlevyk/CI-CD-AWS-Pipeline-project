# Task 3: Secure VPN Access (Tailscale)

Last updated: 2026-03-04


This runbook implements Task 3 secure VPN access controls.

## Scope
- VPN product: Tailscale
- Protected endpoints:
  - `gitlab.omerlevy03.com`
  - `jenkins.omerlevy03.com`
  - `argocd.omerlevy03.com`
  - EKS API endpoint (`*.eks.amazonaws.com`)

## Access Policy

Use role-based groups:
- `group:platform-admins`: full access to GitLab, Jenkins, ArgoCD, and EKS API.
- `group:devops-engineers`: GitLab/Jenkins/ArgoCD UI + read operations on EKS API.
- `group:teammates-ro`: ArgoCD read-only UI only.

Access matrix:

| Resource | platform-admins | devops-engineers | teammates-ro |
|---|---|---|---|
| GitLab | allow | allow | deny |
| Jenkins | allow | allow | deny |
| ArgoCD UI | allow | allow | allow (RO in ArgoCD RBAC) |
| EKS API | allow | limited | deny |

## Tailscale ACL

Base ACL template:
- `docs/templates/tailscale-acl.hujson`
- Auth/MFA checklist:
  - `docs/templates/tailscale-auth-mfa-checklist.md`

Replace placeholders:
- `tag:gitlab`, `tag:jenkins`, `tag:argocd`, `tag:eks-api` with tagged nodes.
- group emails with your identity provider groups.

## Identity And MFA

1. Enable SSO in Tailscale (Google/Microsoft/Okta).
2. Enforce MFA at IdP level for all users.
3. Disable direct auth methods that bypass SSO/MFA.
4. Restrict tailnet join to approved domains/users.

## Network Enforcement

Goal: only VPN clients reach sensitive endpoints.

1. Keep ALB listeners active but lock ALB SG inbound to trusted VPN egress CIDR(s) only.
2. Lock EC2 SGs (GitLab/Jenkins) to ALB SG only.
3. Restrict EKS API CIDRs with authorized VPN egress IP(s).
4. Keep public DNS records, but traffic is blocked unless sourced from VPN-approved CIDRs.

## Validation

Automated script:
```bash
./infra/scripts/validate_vpn_access.sh vpn
./infra/scripts/validate_vpn_access.sh non-vpn
```

Apply sequence (run at final apply stage):
```bash
# 1) Restrict EKS API endpoint CIDRs
terraform -chdir=infra/envs/dev apply -auto-approve \
  -target=module.infrastructure.module.eks.module.eks.aws_eks_cluster.this[0]

# 2) Enforce ArgoCD ALB CIDR restriction
kubectl apply -f gitops/argocd/ingress/argocd-ingress.yaml
```

Manual checks (if needed), from VPN-connected device:
```bash
curl -k -I --max-time 15 https://gitlab.omerlevy03.com
curl -k -I --max-time 15 https://jenkins.omerlevy03.com
curl -k -I --max-time 15 https://argocd.omerlevy03.com
kubectl get nodes
```

From non-VPN device:
```bash
curl -k -I --max-time 15 https://gitlab.omerlevy03.com
curl -k -I --max-time 15 https://jenkins.omerlevy03.com
curl -k -I --max-time 15 https://argocd.omerlevy03.com
```

Expected results:
- VPN: 200/302 from web UIs, successful `kubectl` access.
- Non-VPN: timeout, TLS handshake failure, or 403/blocked.
- Save results in:
  - `docs/validation/task3-vpn-validation.md`

## Teammate Connection Guide

1. Install Tailscale client.
2. Sign in with company SSO.
3. Complete MFA challenge.
4. Verify tailnet status:
```bash
tailscale status
```
5. Test access:
```bash
curl -k -I --max-time 15 https://argocd.omerlevy03.com
```
6. If denied, request membership in the correct Tailscale group.
