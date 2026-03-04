#!/usr/bin/env bash
set -euo pipefail

set -x
getent hosts "${EKS_API_ENDPOINT}" || true
wget -qO- --timeout=10 "https://${EKS_API_ENDPOINT}/version" || true
