#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./infra/scripts/validate_vpn_access.sh vpn
#   ./infra/scripts/validate_vpn_access.sh non-vpn

MODE="${1:-}"
if [[ "$MODE" != "vpn" && "$MODE" != "non-vpn" ]]; then
  echo "usage: $0 <vpn|non-vpn>"
  exit 1
fi

DOMAINS=(
  "gitlab.omerlevy03.com"
  "jenkins.omerlevy03.com"
  "argocd.omerlevy03.com"
)

echo "mode=$MODE"
date -u +"utc=%Y-%m-%dT%H:%M:%SZ"

if [[ "$MODE" == "vpn" ]]; then
  if command -v tailscale >/dev/null 2>&1; then
    tailscale status | sed -n '1,12p'
  else
    echo "tailscale CLI not installed on this host (continuing)"
  fi
fi

all_ok=true

for d in "${DOMAINS[@]}"; do
  code="$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 15 "https://${d}" || true)"
  echo "${d} http_code=${code}"

  if [[ "$MODE" == "vpn" ]]; then
    if [[ "$code" != "200" && "$code" != "301" && "$code" != "302" && "$code" != "307" && "$code" != "308" && "$code" != "401" && "$code" != "403" ]]; then
      all_ok=false
    fi
  else
    if [[ "$code" != "000" && "$code" != "403" ]]; then
      all_ok=false
    fi
  fi
done

if [[ "$MODE" == "vpn" ]]; then
  if command -v kubectl >/dev/null 2>&1; then
    if kubectl get nodes >/dev/null 2>&1; then
      echo "eks_api=reachable"
    else
      echo "eks_api=unreachable"
      all_ok=false
    fi
  else
    echo "kubectl not installed on this host (skipping EKS API check)"
  fi
fi

if [[ "$all_ok" == "true" ]]; then
  echo "result=PASS"
  exit 0
fi

echo "result=FAIL"
exit 2

