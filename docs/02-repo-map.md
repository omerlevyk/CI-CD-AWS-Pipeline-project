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

