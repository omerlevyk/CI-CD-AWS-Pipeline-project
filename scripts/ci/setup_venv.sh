#!/usr/bin/env bash
set -euo pipefail

set -x
python3 -m venv venv
. venv/bin/activate
pip install --upgrade pip
pip install -r python_app/requirements.txt
pip install pylint
pip install bandit
