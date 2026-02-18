# Architecture Overview

## Objective

Deploy a production-style Flask Weather Application on AWS using:

- Private subnet architecture
- Amazon EKS (managed node group)
- Application Load Balancer
- CI/CD with GitLab + Jenkins
- Full Infrastructure as Code using Terraform

---

## High-Level Architecture

The system is built inside a dedicated VPC and follows strict networking rules:

### Public Subnet
- Internet Gateway (IGW)
- Application Load Balancer (ALB)
- NAT Gateway

### Private Subnet
- EC2 GitLab (Dockerized)
- EC2 Jenkins Controller (Dockerized)
- EC2 Jenkins Agent
- Amazon EKS Cluster
  - Managed Node Group (EC2 worker nodes)
  - Kubernetes Deployment (Weather App)
  - ReplicaSet / Pods
  - NodePort Service (internal)

---

## Networking Model

- No EC2 instance has a public IP.
- All outbound traffic from private subnet goes through NAT Gateway.
- All inbound application traffic flows:
  
  Internet → ALB → Target Group → EKS NodePort → Pods

- Route Tables:
  - Public RT → 0.0.0.0/0 → IGW
  - Private RT → 0.0.0.0/0 → NAT Gateway

---

## CI/CD Flow

1. Code pushed to GitLab.
2. GitLab webhook triggers Jenkins pipeline.
3. Jenkins Agent:
   - Builds Docker image
   - Pushes image to DockerHub
   - Deploys to EKS via kubectl / Helm
4. ALB routes traffic to updated pods.

GitLab and Jenkins run outside the Kubernetes cluster.

---

## DNS

- Domain managed via Cloudflare.
- DNS record points to ALB DNS name.
- Cloudflare acts only as DNS (no origin exposure).

---

## Infrastructure as Code

All infrastructure is provisioned via Terraform:

- modules/infra  → VPC + EC2 + EKS + Node Group
- modules/alb    → ALB + Listeners + Target Groups
- modules/k8s    → Kubernetes resources

---

## Diagram

See:

docs/diagrams/system.mmd
