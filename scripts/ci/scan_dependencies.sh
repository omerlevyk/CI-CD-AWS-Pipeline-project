#!/usr/bin/env bash
set -euo pipefail

set -x
trivy fs \
  --scanners vuln \
  --severity CRITICAL \
  --exit-code 1 \
  --no-progress \
  python_app
