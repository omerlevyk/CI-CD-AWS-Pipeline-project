# Weather App Repository

Application source + Jenkins pipeline for building and publishing images.

## Contents
- `python_app/`: Flask weather app.
- `nginx/`: Nginx container image assets.
- `Jenkinsfile`: CI pipeline (runs on dynamic k8s agent pods).
- `scripts/ci/`: CI helper scripts used by Jenkins stages.
- `test_weather_app.py`: tests.

## CI Pipeline Summary (Current)
Pipeline stages in `Jenkinsfile`:
1. EKS connectivity check.
2. Full checkout.
3. Secret scan (`gitleaks`) - fail on leak.
4. Runtime secret loading (Vault-first, Jenkins fallback).
5. Python venv + dependencies.
6. Pylint quality gate.
7. Static analysis (`bandit`) on `main` only.
8. Dependency vulnerability scan (`trivy fs`) with `CRITICAL` fail threshold.
9. Dockerfile/config scan (`trivy config`) with `HIGH,CRITICAL` fail threshold.
10. Build images with Kaniko (`latest`).
11. Prepare versioned release tags.
12. Push versioned images with Kaniko.
13. Sign container images (`cosign`) on `main`.
14. Verify container signatures (`cosign`) on `main` before deploy.
15. Deploy GitOps tag update.

Post actions:
- Slack success/failure notifications.
- Workspace cleanup (with permission normalization for multi-container writes).

## DevSecOps Controls Implemented
- Secret scanning in CI (`gitleaks`) and local pre-commit hook.
- Dependency and Dockerfile scanning via `trivy` with enforced thresholds.
- Python SAST baseline using `bandit`.
- Container signing and pre-deploy verification using `cosign`.

## Client-side Hook
This repo includes a pre-commit hook template for local secret scanning:
- `.githooks/pre-commit` -> runs `gitleaks` on staged content.

Install once per clone:
```bash
./scripts/install-hooks.sh
```

## Jenkins Credentials Required
- `dockerhub` (`usernamePassword`)
- `gitlab-token` (`usernamePassword`)
- `cosign-private-key` (`Secret file`)
- `cosign-public-key` (`Secret file`)
- `cosign-password` (`Secret text`)
- `slack-token` (for notifications)

## Built Images
- `omerlevyk/weather_app-app`
- `omerlevyk/weather_app-nginx`

## Local Run (optional)
```bash
cd python_app
python3 -m venv venv
. venv/bin/activate
pip install -r requirements.txt
python weather_app.py
```
