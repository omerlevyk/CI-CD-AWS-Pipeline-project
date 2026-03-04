#!/usr/bin/env bash
set -euo pipefail

set -x
trivy config \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  --no-progress \
  python_app/Dockerfile nginx/Dockerfile
