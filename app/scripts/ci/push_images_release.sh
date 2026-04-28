#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
. scripts/ci/lib/common.sh

set -x
source_vault_env_if_exists
set_dockerhub_creds_from_vault_if_present
write_docker_config /kaniko/.docker

/kaniko/executor \
  --context "${WORKSPACE}/python_app" \
  --dockerfile "${WORKSPACE}/python_app/Dockerfile" \
  --destination "${APP_IMAGE_RELEASE}"

/kaniko/executor \
  --context "${WORKSPACE}/nginx" \
  --dockerfile "${WORKSPACE}/nginx/Dockerfile" \
  --destination "${NGINX_IMAGE_RELEASE}"
