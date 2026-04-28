#!/usr/bin/env bash
set -euo pipefail

# Bootstrap least-privilege Vault auth/policies for dev consumers.
# Prereq:
# - Vault is initialized and unsealed
# - Operator is authenticated with permissions to manage auth/policies

# 1) Enable/auth backends (idempotent for current Vault versions)
vault auth enable approle || true
vault auth enable kubernetes || true

# 2) Write least-privilege policies
vault policy write jenkins-dev docs/templates/vault-policy-jenkins-dev.hcl
vault policy write weather-dev docs/templates/vault-policy-weather-dev.hcl

# 3) Jenkins AppRole with bounded token lifetime and secret usage count
vault write auth/approle/role/jenkins-dev \
  token_policies="jenkins-dev" \
  token_ttl="1h" \
  token_max_ttl="4h" \
  secret_id_ttl="24h" \
  secret_id_num_uses="20"

echo "jenkins-dev role_id:"
vault read -field=role_id auth/approle/role/jenkins-dev/role-id
echo "jenkins-dev secret_id:"
vault write -field=secret_id -f auth/approle/role/jenkins-dev/secret-id

# 4) Kubernetes auth role for weather service account in default namespace
vault write auth/kubernetes/role/weather-dev \
  bound_service_account_names="weather" \
  bound_service_account_namespaces="default" \
  policies="weather-dev" \
  ttl="1h"

echo "Vault dev bootstrap complete."

