#!/usr/bin/env bash
set -euo pipefail

# Exports TF_VAR_cloudflare_api_token from Vault KV v2.
# Requirements:
# - VAULT_ADDR
# - VAULT_TOKEN (or pre-authenticated vault CLI session)
#
# Optional:
# - VAULT_SECRET_PATH (default: kv/dev/cloudflare/api-token)
# - VAULT_TOKEN_FIELD (default: token)

if ! command -v vault >/dev/null 2>&1; then
  echo "vault CLI is required"
  exit 1
fi

SECRET_PATH="${VAULT_SECRET_PATH:-kv/dev/cloudflare/api-token}"
TOKEN_FIELD="${VAULT_TOKEN_FIELD:-token}"

TOKEN_VALUE="$(vault kv get -field="${TOKEN_FIELD}" "${SECRET_PATH}")"
if [[ -z "${TOKEN_VALUE}" ]]; then
  echo "empty token value from ${SECRET_PATH}"
  exit 2
fi

export TF_VAR_cloudflare_api_token="${TOKEN_VALUE}"
echo "exported TF_VAR_cloudflare_api_token from ${SECRET_PATH}"

