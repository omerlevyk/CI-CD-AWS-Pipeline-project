#!/usr/bin/env bash
set -euo pipefail

set -x
. venv/bin/activate
pylint --fail-under=7.5 python_app/
