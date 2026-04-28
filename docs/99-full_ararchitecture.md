# Full Project Architecture (End-to-End)

Last updated: 2026-03-04


This document is a full technical explanation of the project architecture across infrastructure, application, CI/CD, and GitOps.

It is intentionally comprehensive and written as a system reference.

## 1) System Goal

The platform delivers a production-style weather application stack on AWS with:
- Infrastructure as Code (Terraform)
- CI on Jenkins (running dynamic Kubernetes agents)
- GitOps deployment using ArgoCD
- Runtime workloads on Amazon EKS
- Public access routed through AWS Application Load Balancers
- DNS managed through Cloudflare

The project is split into three operational domains:
- `infra/`: cloud and platform infrastructure
- `app/`: application source code and Jenkins pipeline
- `gitops/`: deployment manifests and desired runtime state

## 2) Repository and Ownership Model

## 2.1 Root structure
- `app/`:
  - Flask weather app
  - Nginx image assets
  - Jenkins pipeline (`Jenkinsfile`)
- `gitops/`:
  - Helm chart for weather + solitaire workloads
  - environment values (`dev-values.yaml`)
  - ArgoCD projects/applications/ingress/secrets templates
- `infra/`:
  - Terraform modules
  - environment entry points (`envs/dev`, `envs/prov`, `envs/test`)
  - helper scripts for operations
- `docs/`:
  - architecture/runbooks/templates/validation evidence

## 2.2 Change ownership rules
- App behavior changes: `app/`
- Runtime Kubernetes desired state: `gitops/`
- Cloud/platform foundational resources: `infra/`
- Operational policy/runbook/how-to content: `docs/`

This separation enables cleaner review boundaries and simpler rollback strategy.

## 3) High-Level Component Inventory

Core components in the live architecture:

1. AWS VPC with public and private subnets
2. Internet Gateway + NAT Gateway for network egress model
3. EKS cluster (v1.32) with managed node group
4. EKS add-ons:
   - `aws-ebs-csi-driver`
   - `aws-efs-csi-driver`
5. AWS ALB for GitLab/Jenkins/weather host routing
6. ALB Controller IAM/OIDC integration
7. GitLab EC2 instance (private subnet)
8. Jenkins controller EC2 instance (private subnet)
9. Jenkins dynamic agents in EKS pods
10. Weather and solitaire application workloads in Kubernetes
11. EFS-backed persistent history volume for weather app
12. ArgoCD control plane in `argocd` namespace
13. ArgoCD app (`weather-stack-dev`) syncing from GitOps repo
14. Cloudflare DNS CNAME records
15. Vault integration artifacts for runtime secret retrieval (Terraform/Jenkins/ArgoCD bootstrap)

## 4) Network Architecture

## 4.1 VPC topology
The Terraform VPC module provisions:
- One VPC (`10.0.0.0/16`)
- Two public subnets
- Two private subnets
- Internet Gateway (public ingress/egress path)
- NAT Gateway in a public subnet
- Public and private route tables
- Private default route to NAT for outbound internet from private compute

## 4.2 Subnet placement strategy
- Public subnets: ALB-facing resources and internet-path primitives
- Private subnets:
  - GitLab EC2
  - Jenkins controller EC2
  - EKS worker nodes

This design keeps application/platform compute off direct public IP exposure.

## 4.3 Security groups and ingress model
`infra/modules/security_groups` defines:
- `alb_sg`: inbound HTTP/HTTPS constrained by configured CIDRs
- `private_instances_sg`: allows traffic from ALB SG and controlled SSH paths
- `bastion_sg`: SSH rule scope (as defined in current module)

Important path controls:
- ALB ingress CIDRs are parameterized and now tied to VPN-allowed CIDRs in env config.
- EKS API public endpoint CIDRs are similarly parameterized.

## 4.4 Public endpoints and host routing
Current externally routed hosts:
- `gitlab.<domain>`
- `jenkins.<domain>`
- `weather.<domain>`
- `solitaire.<domain>` (K8s ingress path)
- `argocd.<domain>` (ArgoCD ingress)

`infra/modules/alb` handles:
- ALB creation
- HTTPS listener with ACM certificate
- host-based listener rules for GitLab/Jenkins/weather
- target groups + health checks

ArgoCD is exposed through an ingress in the `gitops` repo and managed by the ALB controller.

## 5) Compute and Platform Layer

## 5.1 EKS cluster
The EKS module uses `terraform-aws-modules/eks/aws` and includes:
- Cluster version `1.32`
- Public + private endpoint support
- Public API CIDR allow list support
- IRSA enabled
- Managed node group (`t3.medium`, autoscaling bounds in module config)

## 5.2 Add-ons and storage drivers
Enabled EKS add-ons:
- EBS CSI Driver
- EFS CSI Driver

EFS CSI is required for shared write access (`ReadWriteMany`) used by weather history persistence.

## 5.3 EC2 platform services
Terraform creates EC2 instances for:
- GitLab
- Jenkins controller
- Optional Jenkins agent (toggle `create_jenkins_agent`, currently disabled in dev tfvars)

GitLab bootstrap is automated with `user_data` in Terraform composition module.

## 6) Application Runtime Architecture

## 6.1 Workloads
The Helm chart in `gitops/apps/weather-stack/chart` deploys:
- `weather-deployment`
- `solitaire-deployment`

Services:
- `weather-service` NodePort 32300
- `solitaire-service` NodePort 32400

## 6.2 Probes and resilience
Weather deployment includes:
- `startupProbe`
- `readinessProbe`
- `livenessProbe`

Probe values are centralized in Helm values and environment overlays.

## 6.3 Persistence model
Weather app writes search history to mounted path `/app/history`.

Persistence resources:
- EFS-backed `StorageClass`
- PVC with `ReadWriteMany`

This supports multi-replica access across nodes, unlike single-node EBS RWO behavior.

## 6.4 App internals (weather service)
The Flask app includes:
- City search and weather retrieval from external APIs
- Input validation and error handling abstractions
- Daily weather structuring and humidity extraction
- Search history file persistence
- Prometheus metrics endpoint (`/metrics`)
- Optional DynamoDB save endpoint (`/api/save`)
- UI with visible release indicator content in template

## 7) CI Architecture (Jenkins)

## 7.1 Jenkins execution topology
- Controller on EC2
- Build agents as Kubernetes pods (Jenkins Kubernetes plugin behavior via pipeline pod spec)

Agent pod includes:
- `python` container for lint/setup/test logic
- `kaniko` container for container build/push without Docker daemon
- `gitleaks` container for secret scanning
- `trivy` container for dependency and Dockerfile scanning
- `cosign` container for image signing and verification

## 7.2 Pipeline flow
Current Jenkins stages:
1. EKS connectivity check
2. Full checkout
3. Secret scan (`gitleaks`)
4. Load runtime secrets (Vault-first, fallback to Jenkins credentials)
5. Setup Python virtual environment
6. Pylint quality gate
7. Static analysis (`bandit`, main only)
8. Dependency scan (`trivy fs`, CRITICAL)
9. Dockerfile scan (`trivy config`, HIGH/CRITICAL)
10. Build images (latest tags)
11. Compute release tag
12. Push release-tagged images
13. Sign container images (`cosign`, main only)
14. Verify container signatures (`cosign`, main only, before deploy)
15. Deploy stage updates GitOps values and pushes to GitOps `dev`

## 7.3 Artifact and release strategy
Produced images:
- `omerlevyk/weather_app-app`
- `omerlevyk/weather_app-nginx`

Versioning strategy:
- explicit versioned tags (`v1.0.<build>-<timestamp>`)

## 7.4 GitOps handoff from CI
Jenkins updates:
- `gitops/apps/weather-stack/envs/dev-values.yaml` tag field

Then pushes to `gitops` `dev` branch, followed by merge gate to `main`.

## 8) GitOps Architecture (ArgoCD + Helm)

## 8.1 ArgoCD project/application model
Key resources:
- AppProject: `apps`
- Application: `weather-stack-dev`

Application source points to:
- repo URL: GitLab GitOps repo
- branch: `main`
- chart path: `apps/weather-stack/chart`
- values file: `../envs/dev-values.yaml`

Sync policy:
- automated
- prune enabled
- self-heal enabled

## 8.2 Ingress and exposure
ArgoCD ingress manifest provides:
- host: `argocd.<domain>`
- ALB annotations for listener/cert/redirect/health checks
- inbound CIDR restriction annotation for VPN pathing

## 8.3 Access control
ArgoCD read-only teammate model implemented with:
- RBAC policies for app/log read
- explicit deny-by-absence for sync/delete
- dedicated account (`teammate-ro`)

## 9) DNS Architecture (Cloudflare)

Terraform `dns` module manages CNAME records for platform hosts by mapping:
- subdomain -> ALB DNS hostname

Cloudflare API token is provided at runtime (not stored in tracked tfvars).

## 10) Secrets and Security Architecture

## 10.1 Runtime secret strategy
Target state is Vault-based retrieval with least privilege:
- Terraform provider token via env (`TF_VAR_cloudflare_api_token`) with helper script
- Jenkins runtime secret fetch from Vault AppRole, fallback to Jenkins credentials if unavailable
- ArgoCD repo credential secret render/apply from Vault helper script

## 10.2 Vault policy model
Defined templates:
- `docs/templates/vault-policy-jenkins-dev.hcl`
- `docs/templates/vault-policy-weather-dev.hcl`

Bootstrap helper:
- `docs/templates/vault-bootstrap-dev.sh`

## 10.3 Network hardening path
VPN task artifacts include:
- CIDR-driven ALB and EKS API access controls
- Tailscale ACL template
- MFA checklist
- validation scripts/logs

## 11) Storage Architecture

## 11.1 EFS for shared app history
Weather history uses EFS-backed PVC to guarantee:
- shared write access
- persistence across pod restarts
- safer multi-node scale behavior

## 11.2 State and drift model
Terraform state is local in env folder in current setup.
Operationally, this implies:
- careful state backup
- controlled operator process
- explicit drift checks before apply/destroy

## 12) Delivery Lifecycle (End-to-End)

1. Developer commits app code to app repo branch.
2. GitLab triggers Jenkins pipeline.
3. Jenkins runs security gates + lint/build/push/sign/verify.
4. Jenkins updates GitOps values with new image tag and pushes to `gitops/dev`.
5. Team approves merge `gitops/dev -> gitops/main`.
6. ArgoCD detects desired-state change and syncs cluster.
7. ALB routes external traffic to updated workloads.

## 13) Operational Validation and Runbooks

Core runbooks:
- `docs/05-operations-runbook.md`
- `docs/06-vpn-access-tailscale.md`
- `docs/07-vault-secrets-migration.md`

Validation evidence files:
- `docs/validation/task3-vpn-validation.md`
- `docs/validation/task4-secret-rotation-validation.md`

## 14) Environment and Module Design

Environment entry points:
- `infra/envs/dev` (active)
- `infra/envs/prov` (scaffold)
- `infra/envs/test` (scaffold)

Reusable modules:
- `vpc`, `security_groups`, `ec2`, `eks`, `alb`, `alb_controller`, `dns`, `infra` composition

This keeps environment-specific values separate from reusable infrastructure logic.

## 15) Critical Dependencies

Cloud dependencies:
- AWS (EC2, EKS, ALB, IAM, EFS, ACM)
- Cloudflare DNS API

Tooling dependencies:
- Terraform
- kubectl
- aws cli
- Jenkins + Kubernetes plugin
- ArgoCD
- Helm
- Vault (migration path)

Application dependencies:
- Flask/Python runtime
- Open-Meteo APIs
- DockerHub registry

## 16) Failure Domains and Known Risks

1. Cloudflare token missing/invalid:
   - blocks Terraform operations touching DNS resources
2. Local Terraform state model:
   - risk of operator mismatch without strict process
3. CI secret provider availability:
   - Vault fallback behavior currently protects pipeline continuity, but full cutover requires validated Vault uptime/auth
4. Long-running EKS operations:
   - apply/destroy can take significant time due managed control plane/nodegroup operations

## 17) Rebuild and Disaster Recovery Perspective

With valid AMIs and Terraform inputs, the stack can be recreated from scratch by:
- `terraform apply` in `infra/envs/dev`
- restoring GitOps/ArgoCD manifests
- restoring required secrets and credentials
- running CI once to seed image/tag flow

Key prerequisite artifacts for rebuild:
- AMI IDs for GitLab/Jenkins controller (golden images)
- ACM certificate ARN
- Cloudflare zone details + API token
- git/app/gitops repositories and access tokens

## 18) Current Status Snapshot

Implemented:
- Infrastructure composition and modularization
- CI + GitOps flow
- Health probes and rollout discipline
- Shared persistence with EFS
- Project-level docs structure
- VPN and Vault implementation artifacts

Pending live execution/verification:
- Final VPN hardening apply + non-VPN block validation
- Vault bootstrap in live env
- Secret rotation evidence run

## 19) Architecture Summary

This project is an integrated DevOps reference architecture where:
- Terraform builds and wires platform foundations
- Jenkins produces versioned artifacts and updates desired runtime state
- ArgoCD continuously reconciles Kubernetes to Git
- AWS ALB + Cloudflare provide external access routing
- EFS ensures shared persistence for scaled weather workloads
- VPN + Vault tracks move security posture from baseline to hardened operations

