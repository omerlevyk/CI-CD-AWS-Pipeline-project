# Architecture Overview

Last updated: 2026-03-04

## Objective
Run a production-style weather platform on AWS with IaC + CI/CD + GitOps.

## High-Level Components
- **Networking**: VPC, public/private subnets, IGW, NAT.
- **Platform**: EKS cluster + managed node group.
- **CI**: Jenkins controller on EC2, dynamic agents on EKS pods.
- **SCM**: Self-hosted GitLab.
- **Ingress**: AWS ALB (internet-facing).
- **GitOps**: ArgoCD syncs from `gitops` repo.

## Traffic Flow
- User -> ALB -> Ingress -> Kubernetes Service -> Pods
- Developer -> GitLab -> Jenkins -> DockerHub -> GitOps update -> ArgoCD sync

## Security/Isolation Model
- Compute workloads run in private subnets.
- Public entry is controlled through ALB listeners/rules.
- Kubernetes API access controlled by IAM/RBAC.
- CI includes shift-left security gates (`gitleaks`, `bandit`, `trivy`).
- Container artifacts are signed and verified (`cosign`) before deployment.

## DNS
- Cloudflare manages DNS.
- App hosts (`weather`, `solitaire`) and platform hosts (`gitlab`, `jenkins`, `argocd`) resolve to ALB endpoints.
