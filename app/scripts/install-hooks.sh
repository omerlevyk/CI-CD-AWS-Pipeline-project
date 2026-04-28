#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

git config core.hooksPath .githooks
chmod +x .githooks/pre-commit

echo "Git hooks installed. core.hooksPath=.githooks"
echo "Pre-commit hook: gitleaks secret scan on staged changes"
