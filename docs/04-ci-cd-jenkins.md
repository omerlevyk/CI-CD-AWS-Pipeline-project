# CI/CD Architecture

This project uses GitLab + Jenkins for deployment automation.

---

## Flow

1. Developer pushes code to GitLab.
2. GitLab triggers Jenkins via webhook.
3. Jenkins pipeline runs.
4. Docker image is built.
5. Image pushed to DockerHub.
6. Deployment updated in EKS.

---

## Jenkins Requirements

Installed on:

- Jenkins Controller (Dockerized)
- Jenkins Agent (EC2)

Agent must have:

- Docker
- AWS CLI
- kubectl
- Helm
- Git

---

## Required Jenkins Credentials

- DockerHub credentials
- AWS credentials
- GitLab credentials (if needed)

---

## Pipeline Stages

Typical stages:

- Connection Test
- Clean workspace
- Checkout code
- Build Docker image
- Tag image
- Push image
- Update Kubernetes deployment

Defined in:

Jenkinsfile (root of repo)

---

## Kubernetes Deployment Update

Pipeline runs:

kubectl apply -f k8s/

or

helm upgrade --install


depending on implementation.

