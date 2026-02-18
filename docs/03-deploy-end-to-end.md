# End-to-End Deployment Guide

This guide recreates the full system from scratch.

---

# Step 1 — Clone Repository
git clone https://git.infinitylabs.co.il/ilrd/ramat-gan/do27/omer.levy/-/tree/main/projects/terraform_eks

---

# Step 2 — Configure Terraform Variables

Edit:

modules/infra/terraform.tfvars
modules/alb/terraform.tfvars

Fill:

- Region
- CIDR ranges
- Key name
- Instance types
- Domain
- Docker image

---

# Step 3 — Deploy Infrastructure

cd modules/infra
terraform init
terraform apply

Wait until:

- VPC created
- EC2 instances created
- EKS cluster ready
- Node group active

---

# Step 4 — Deploy ALB

cd ../alb
terraform init
terraform apply

Validate ALB exists.

---

# Step 5 — Connect to EKS

aws eks update-kubeconfig --region <region> --name <cluster_name>
kubectl get nodes


---

# Step 6 — Deploy Kubernetes Resources

cd ../k8s
terraform init
terraform apply

Validate:

kubectl get pods
kubectl get svc

---

# Step 7 — Configure DNS

In Cloudflare:

Create record:

weather.example.com → ALB DNS name

---

# Step 8 — Validate End Result

Access:

https://app.example.com

Confirm:

- ALB routes correctly
- Pods running
- App responding

