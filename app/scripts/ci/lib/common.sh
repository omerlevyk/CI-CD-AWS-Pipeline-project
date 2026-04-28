#!/usr/bin/env bash
set -euo pipefail

source_vault_env_if_exists() {
  if [[ -f "${WORKSPACE}/.vault_env" ]]; then
    # shellcheck disable=SC1090
    . "${WORKSPACE}/.vault_env"
  fi
}

set_dockerhub_creds_from_vault_if_present() {
  if [[ -n "${VAULT_DH_USER:-}" && -n "${VAULT_DH_TOKEN:-}" ]]; then
    DH_USER="${VAULT_DH_USER}"
    DH_TOKEN="${VAULT_DH_TOKEN}"
    echo "Using Vault runtime DockerHub credentials"
  else
    echo "Using Jenkins credential store for DockerHub"
  fi
}

write_docker_config() {
  local target_dir="$1"
  mkdir -p "${target_dir}"
  cat > "${target_dir}/config.json" <<JSON
{
  "auths": {
    "https://index.docker.io/v1/": {
      "auth": "$(printf '%s:%s' "$DH_USER" "$DH_TOKEN" | base64 | tr -d '\\n')"
    }
  }
}
JSON
}
