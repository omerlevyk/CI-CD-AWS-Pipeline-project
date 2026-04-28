#!/usr/bin/env bash
set -euo pipefail

# Render ArgoCD repo credentials Secret from Vault KV and apply to cluster.
# Requirements:
# - vault CLI configured and authenticated
# - kubectl configured for target cluster
#
# Optional env vars:
# - VAULT_REPO_SECRET_PATH (default: kv/dev/argocd/repo-credentials)
# - ARGOCD_NAMESPACE (default: argocd)
# - REPO_URL (default: https://gitlab.omerlevy03.com/omerlevyk/gitops.git)

if ! command -v vault >/dev/null 2>&1; then
  echo "vault CLI is required"
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required"
  exit 1
fi

SECRET_PATH="${VAULT_REPO_SECRET_PATH:-kv/dev/argocd/repo-credentials}"
NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
REPO_URL="${REPO_URL:-https://gitlab.omerlevy03.com/omerlevyk/gitops.git}"

USERNAME="$(vault kv get -field=username "${SECRET_PATH}")"
PASSWORD="$(vault kv get -field=token "${SECRET_PATH}")"

if [[ -z "${USERNAME}" || -z "${PASSWORD}" ]]; then
  echo "missing username/token in ${SECRET_PATH}"
  exit 2
fi

kubectl -n "${NAMESPACE}" apply -f - <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: gitops-repo-credentials
  namespace: ${NAMESPACE}
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  url: ${REPO_URL}
  type: git
  username: ${USERNAME}
  password: ${PASSWORD}
YAML

echo "applied gitops-repo-credentials in namespace ${NAMESPACE}"

