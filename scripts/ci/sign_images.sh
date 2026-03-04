#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
. scripts/ci/lib/common.sh

set -x
source_vault_env_if_exists
set_dockerhub_creds_from_vault_if_present
write_docker_config "${WORKSPACE}/.docker"
export DOCKER_CONFIG="${WORKSPACE}/.docker"

cosign sign --yes --key "${COSIGN_PRIVATE_KEY_FILE}" "${APP_IMAGE_RELEASE}"
cosign sign --yes --key "${COSIGN_PRIVATE_KEY_FILE}" "${NGINX_IMAGE_RELEASE}"
