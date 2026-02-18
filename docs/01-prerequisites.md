# Prerequisites

This document lists everything required to reproduce the project end-to-end.

---

## Required Accounts

- AWS Account
- DockerHub Account
- GitLab Account
- Cloudflare Account

---

## Required Local Tools

Install:

- Terraform >= 1.5
- AWS CLI
- kubectl
- Helm
- Docker
- Git

---

## Required AWS Configuration

Before running Terraform:

- IAM roles already created for:
  - GitLab EC2
  - Jenkins Controller EC2
  - Jenkins Agent EC2
- IAM roles for:
  - EKS Cluster
  - EKS Node Group

- AWS credentials configured locally:

aws configure

---

## Required Secrets / Variables

Terraform requires:

- AWS region
- VPC CIDR
- Subnet CIDRs
- Key pair name
- DockerHub credentials
- Domain name
- Cloudflare DNS zone

Variables are defined inside:
modules/*/variables.tf

---

## DockerHub

The Weather App image must exist or be buildable by Jenkins.

Repository example:
dockerhub-username/weather-app

---

## Kubernetes Access

After infrastructure is created:

aws eks update-kubeconfig --region <region> --name <cluster_name>

Validate:

kubectl get nodes

# Repository Structure

This document explains where everything is located.

---

## Root

- README.md → Project overview
- docs/ → Documentation
- modules/ → Terraform modules

---

## modules/infra

Responsible for:

- VPC
- Subnets
- Route Tables
- Internet Gateway
- NAT Gateway
- EC2 Instances
- EKS Cluster
- EKS Managed Node Group

Entry file:
modules/infra/main.tf

---

## modules/alb

Responsible for:

- Application Load Balancer
- Target Groups
- Listeners
- Listener Rules
- Target group for EKS NodePort

Entry file:
modules/alb/main.tf

---

## modules/k8s

Responsible for applying:

- Deployment
- Service (NodePort)
- Namespace
- ConfigMaps (if exist)

Applied after EKS is ready.

---

## CI/CD

- Jenkinsfile → Pipeline definition
- Dockerfile → Weather App container build
- requirements.txt → Python dependencies

---

## Diagrams

docs/diagrams/system.mmd

