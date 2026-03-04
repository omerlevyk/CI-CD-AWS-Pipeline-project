#!/usr/bin/env bash
set -euo pipefail

set -x
gitleaks detect --source . --redact --no-banner --exit-code 1
