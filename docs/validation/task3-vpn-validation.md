# Task 3 Validation Log

Last updated: 2026-03-04


## Preconditions
- Terraform applied with VPN CIDRs for:
  - ALB ingress (`alb_ingress_cidrs`)
  - EKS API public endpoint (`cluster_endpoint_public_access_cidrs`)
- ACL applied in Tailscale admin using:
  - `docs/templates/tailscale-acl.hujson`

## Run Commands

From VPN-connected client:
```bash
./infra/scripts/validate_vpn_access.sh vpn
```

From non-VPN client:
```bash
./infra/scripts/validate_vpn_access.sh non-vpn
```

## Results
- VPN client result: `PENDING`
- non-VPN client result: `FAIL` (2026-02-21 UTC, before final apply)
  - `gitlab.omerlevy03.com` -> `302`
  - `jenkins.omerlevy03.com` -> `403`
  - `argocd.omerlevy03.com` -> `200`

## Expected
- VPN: PASS
- non-VPN: PASS
