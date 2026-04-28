# Operations Runbook

Last updated: 2026-03-04

## Quick Health Checks
```bash
kubectl get nodes
kubectl get pods -A
kubectl get deploy,svc,ingress -A
kubectl get application -n argocd
```

## App-Specific Checks
```bash
kubectl get pods -n default -l app=weather
kubectl describe deploy weather-deployment -n default
kubectl logs -n default deploy/weather-deployment --tail=100
```

## ArgoCD Checks
```bash
kubectl get pods -n argocd
kubectl get application -n argocd weather-stack-dev -o yaml | rg 'sync:|health:'
```

## Jenkins Dynamic Agent Checks
- In Jenkins build log, verify pod creation in `k8s-agent` namespace.
- Verify stages run in expected containers:
  - `python` (lint/static/runtime secret setup)
  - `kaniko` (build/push)
  - `gitleaks` (secret scan)
  - `trivy` (dependency/Dockerfile scan)
  - `cosign` (sign/verify)

## Common Issues

### 1) Jenkins pod not scheduled / unauthorized
- Check Jenkins cloud namespace/service account.
- Check RBAC permissions for `jenkins-k8s`.
- If using short-lived SA token in Jenkins cloud, rotate token and update credential.

### 2) ArgoCD app not syncing
- Check repo credentials secret.
- Check app source path/branch.
- Check target namespace permissions.

### 3) ALB ingress unhealthy
- Check ingress annotations and host rules.
- Check AWS Load Balancer Controller status.
- Check SG rules and target health.

### 4) Image pull failures
- Verify image tag exists.
- Verify registry credentials/pull secrets.

### 5) Deploy stage GitLab push 403
- Validate `gitlab-token` credentials in Jenkins.
- Validate token scope (`read_repository`, `write_repository`) and role on `gitops` repo.
- Verify branch protection settings for target branch.

### 6) Signature verify failure
- Confirm `cosign-public-key` matches signing private key.
- Confirm images were signed for the exact pushed tag.

## Safe Recovery Actions
```bash
kubectl rollout restart deployment/weather-deployment -n default
kubectl rollout status deployment/weather-deployment -n default
```
