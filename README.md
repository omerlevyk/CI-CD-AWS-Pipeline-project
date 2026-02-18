
# AWS EKS Deployment Project

<div align="center">

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Jenkins](https://img.shields.io/badge/jenkins-%232C5263.svg?style=for-the-badge&logo=jenkins&logoColor=white)
![GitLab](https://img.shields.io/badge/gitlab-%23181717.svg?style=for-the-badge&logo=gitlab&logoColor=white)

**Private Cloud Infrastructure with Automated CI/CD Pipeline**

[Architecture](#architecture) •
[Pipeline](#cicd-flow) •
[Deployment](#how-to-deploy)

</div>


# Python Weather App on AWS (EKS + Private Subnets) – Terraform

<p align="center">
  <img src="docs/diagrams/project_diagram.png" width="900">
</p>

---

## Overview

Production-like deployment of a containerized Flask Weather application on AWS using a private-network architecture and fully managed Infrastructure as Code.

The project demonstrates how a real DevOps environment is built — not just running containers, but operating a secure platform.

### Main Goals

* No public EC2 instances
* Kubernetes running inside private subnets
* Only ALB exposed to internet
* Full CI/CD pipeline
* Fully reproducible environment via Terraform

---

## Architecture

### Networking

* VPC
* Public Subnets → ALB, NAT Gateway
* Private Subnets → EKS + CI servers
* Internet access only through NAT
* Inbound traffic only through ALB

### Compute

* EC2 GitLab (source control)
* EC2 Jenkins Controller
* EC2 Jenkins Agent
* AWS EKS Cluster (Managed Node Group)

### Application Flow

Developer → GitLab → Jenkins → DockerHub → EKS → ALB → Client

---

## Infrastructure as Code

Everything is provisioned using Terraform modules:

| Module | Responsibility                    |
| ------ | --------------------------------- |
| infra  | VPC, subnets, routing, EC2, EKS   |
| alb    | Load balancer, listeners, routing |
| k8s    | Kubernetes deployment resources   |

---

## CI/CD Pipeline

1. Developer pushes code
2. GitLab webhook triggers Jenkins
3. Jenkins builds Docker image
4. Image pushed to DockerHub
5. Kubernetes deployment updated
6. Traffic served via ALB

Detailed steps → docs/04-ci-cd-jenkins.md

---

## Repository Structure

```
modules/
  infra/
  alb/
  k8s/

docs/
  diagrams/
  deploy/
  runbook/
```

Full mapping → docs/02-repo-map.md

---

## Deployment

End-to-end deployment instructions:
→ docs/03-deploy-end-to-end.md

---

## Operations / Troubleshooting

Health checks, debugging and maintenance:
→ docs/05-operations-runbook.md

---

## Key Concepts Demonstrated

* Private subnet architecture
* Kubernetes production topology
* Immutable infrastructure
* CI/CD automation
* Infrastructure as Code best practices
* Secure ingress design


### Code Standards

- **Terraform**: Follow [HashiCorp style guide](https://www.terraform.io/docs/language/syntax/style.html)
- **Kubernetes**: Use proper resource limits and labels
- **Shell Scripts**: Use ShellCheck for linting
- **Documentation**: Keep README and docs up to date

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Authors

- **Omer Levy** - *DevOps Engineer* - [@omerlevyk](https://github.com/omerlevyk)

### Acknowledgments

- AWS documentation and examples
- Terraform community modules
- Kubernetes community
- HashiCorp tutorials
- DevOps course instructors

---

## 📞 Support

If you have questions or need help:

1. **Check the documentation** in the `docs/` directory
2. **Search existing issues** on GitHub
3. **Create a new issue** with detailed information
4. **Contact the team** via Slack: `#devops-course`

---

## 🗺️ Roadmap


### Current Implementation
- ✅ EKS cluster in private subnets
- ✅ Terraform-provisioned infrastructure
- ✅ CI/CD pipeline using GitLab and Jenkins
- ✅ Helm-based Kubernetes deployment templates
- ✅ Weather persistence moved to EFS (RWX)
- ✅ Application traffic exposed via ALB ingress
- ✅ Repository split started: `infra/` (Terraform), `app/` (source), `gitops/` (deployment state)
- 🚧 ArgoCD migration in progress (GitOps repo and manifests created)

### Possible Improvements
- 🔄 Install ArgoCD and expose it through ingress
- 🔄 Connect ArgoCD to the `gitops/` repository
- 🔄 Move final app deployment ownership from Terraform runtime state to ArgoCD sync
- 🔄 Update CI to commit image tag changes into `gitops/` values files
- 🔄 Add pipeline test stage and quality gates

### Future Exploration
- 📋 secret manager - 3h
- 📋 secure VPN access - 2h
- 📋 dynamic pod agents - 3h
- 📋 multiple ALBs - 2h
- 📋 health probes - 1h
- 📋 branching strategies & signed commits - 1h
- 📋 multi-environment terraform (dev / prov / test) - 2h
- 📋 terraform remote backend + state locking (S3 + DynamoDB) - 2h


---

<div align="center">

**Built with ❤️ for DevOps Excellence via learning and practice**

[![Made with Terraform](https://img.shields.io/badge/Made%20with-Terraform-623CE4)](https://www.terraform.io/)
[![Powered by AWS](https://img.shields.io/badge/Powered%20by-AWS-FF9900)](https://aws.amazon.com/)
[![Kubernetes](https://img.shields.io/badge/Orchestrated%20with-Kubernetes-326CE5)](https://kubernetes.io/)

[⬆ Back to Top](#devops-infrastructure-project)

</div>
