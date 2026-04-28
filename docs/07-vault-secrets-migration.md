# Task 4: Secret Manager Migration (HashiCorp Vault)

Last updated: 2026-03-04


This runbook implements Task 4 Vault secret management migration.

## Objectives
- Remove plaintext/static secrets from repos and ad-hoc configs.
- Store secrets in Vault KV v2 with env-scoped naming.
- Apply least-privilege access for Jenkins and workloads.
- Define rotation and emergency revocation procedures.

## Environment-Scoped Naming

Use this path convention:
- `kv/dev/<system>/<secret_name>`
- `kv/prod/<system>/<secret_name>`

Examples:
- `kv/dev/jenkins/dockerhub`
- `kv/dev/argocd/repo-credentials`
- `kv/dev/cloudflare/api-token`
- `kv/dev/aws/terraform-deployer`

## Current Secret Inventory And Mapping

Primary inventory file:
- `docs/templates/secrets-inventory.csv`

Immediate finding from current repo:
- `infra/envs/dev/terraform.tfvars` was previously storing a live token in plaintext.
- Current state: token removed from tracked tfvars and now expected via runtime environment export.

Action:
1. Rotate exposed credentials.
2. Replace with runtime/secure injection (env vars, Vault agent, or CI credentials provider).
3. Keep only placeholders in tracked files.

## Vault Policies

Reference policies:
- Jenkins policy: `docs/templates/vault-policy-jenkins-dev.hcl`
- Weather workload policy: `docs/templates/vault-policy-weather-dev.hcl`

Apply:
```bash
vault policy write jenkins-dev docs/templates/vault-policy-jenkins-dev.hcl
vault policy write weather-dev docs/templates/vault-policy-weather-dev.hcl
```

Bootstrap helper:
```bash
./docs/templates/vault-bootstrap-dev.sh
```

## Auth Model

Recommended:
- Jenkins: Vault AppRole (or OIDC/JWT if already available in CI).
- Kubernetes workloads: Vault Kubernetes auth per service account.

Kubernetes auth example (adapt names as needed):
```bash
vault auth enable kubernetes
vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
  token_reviewer_jwt="$TOKEN_REVIEWER_JWT" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

vault write auth/kubernetes/role/weather-dev \
  bound_service_account_names=weather \
  bound_service_account_namespaces=default \
  policies=weather-dev \
  ttl=1h
```

## Replace Static Secret Usage

Migration targets:
1. Terraform: remove real secrets from `terraform.tfvars`; inject via CI env vars.
  - helper: `infra/scripts/export_tf_var_cloudflare_from_vault.sh`
2. Jenkins: pipeline supports Vault runtime retrieval first, with Jenkins credentials fallback.
  - implementation: `app/Jenkinsfile` stage `Load Runtime Secrets`
3. ArgoCD repo credentials: source token from Vault during secret bootstrap.
  - helper: `gitops/argocd/scripts/render_repo_credentials_from_vault.sh`
4. App runtime: consume secrets from Vault (Vault agent injector or startup fetch).

## Least Privilege Rules

- Jenkins should have write access only to required paths (for example `kv/dev/jenkins/*`).
- App workloads should only read their own env/app path (for example `kv/dev/weather/*`).
- No wildcard access to all environments.
- Separate `dev` and `prod` policies.

## Rotation Procedure

1. Pick one secret (for example DockerHub token).
2. Create new token in provider.
3. Write new value to Vault path.
4. Trigger workload/CI reload.
5. Validate pipeline/app health.
6. Revoke old token.

Validation example:
```bash
# Pipeline still authenticates and pushes
# App still starts and serves requests
kubectl get pods -n default -l app=weather
kubectl logs -n default deploy/weather-deployment --tail=100
```

Record results in:
- `docs/validation/task4-secret-rotation-validation.md`

## Emergency Revocation

1. Disable compromised credential at provider side first.
2. Remove/rewrite secret value in Vault.
3. Revoke affected Vault tokens or auth role.
4. Restart workloads and rerun pipeline with fresh credentials.
5. Audit Vault and CI logs for suspicious access.
