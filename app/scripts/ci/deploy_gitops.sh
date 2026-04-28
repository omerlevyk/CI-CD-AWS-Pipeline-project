#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
. scripts/ci/lib/common.sh

set -x
source_vault_env_if_exists

if [[ -n "${VAULT_GL_USER:-}" && -n "${VAULT_GL_TOKEN:-}" ]]; then
  GL_USER="${VAULT_GL_USER}"
  GL_TOKEN="${VAULT_GL_TOKEN}"
  echo "Using Vault runtime GitLab credentials"
else
  echo "Using Jenkins credential store for GitLab"
fi

rm -rf gitops-deploy
git clone "https://${GL_USER}:${GL_TOKEN}@gitlab.omerlevy03.com/omerlevyk/gitops.git" gitops-deploy
cd gitops-deploy

git config user.name "jenkins-ci"
git config user.email "jenkins@omerlevy03.com"

VALUES_FILE="apps/weather-stack/envs/dev-values.yaml"
sed -i -E "s|(^[[:space:]]*tag:[[:space:]]*).*$|\\1${RELEASE_TAG}|" "${VALUES_FILE}"

if git diff --quiet -- "${VALUES_FILE}"; then
  echo "No deploy change detected in ${VALUES_FILE}"
  exit 0
fi

git add "${VALUES_FILE}"
git commit -m "ci(gitops): deploy weather image ${RELEASE_TAG} from ${JOB_NAME} #${BUILD_NUMBER}"
git push origin HEAD:dev
