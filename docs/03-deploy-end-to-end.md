# End-to-End Deployment (Current Flow)

Last updated: 2026-03-04

## 1) Provision infrastructure (Terraform)
```bash
cd /home/omer/working_dir/devops_project/infra/envs/dev
source ../../scripts/load_infra_env.sh
terraform init
terraform apply
```

## 2) Configure kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name weather-app-eks
kubectl get nodes
```

## 3) Verify platform controllers
- AWS Load Balancer Controller running.
- ArgoCD running in `argocd` namespace.

```bash
kubectl get pods -n kube-system
kubectl get pods -n argocd
```

## 4) Apply GitOps manifests
From `gitops` repo:
```bash
kubectl apply -f argocd/projects/apps-project.yaml
kubectl apply -f argocd/applications/weather-stack-dev.yaml
```

## 5) Trigger CI pipeline (app repo)
- Push/merge app change.
- Jenkins pipeline executes security gates and artifact flow:
  - `gitleaks` secret scan
  - `bandit` SAST (`main`)
  - `trivy fs` dependency scan
  - `trivy config` Dockerfile/config scan
  - image build/push
  - `cosign` sign + verify (`main`)
  - GitOps tag update

## 6) Verify app deployment
```bash
kubectl get application -n argocd weather-stack-dev
kubectl get pods -n default
kubectl get ingress -n default
```

## 7) Validate external access
- `weather.<your-domain>`
- `solitaire.<your-domain>`
- `argocd.<your-domain>`

## Notes
- Runtime changes flow through `gitops` + ArgoCD sync.
- Deployment is gated by security stages and signature verification before `Deploy` stage.
