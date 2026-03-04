#!/usr/bin/env bash
set -euo pipefail

set -x
. venv/bin/activate
bandit -r python_app -ll -iii
