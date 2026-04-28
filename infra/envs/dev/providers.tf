terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "omerlevyk-tf-state-516608940168"
    key            = "infra/envs/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "aws_eks_cluster" "this" {
  count = var.enable_k8s_providers ? 1 : 0
  name  = module.infrastructure.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  count = var.enable_k8s_providers ? 1 : 0
  name  = module.infrastructure.cluster_name
}

locals {
  eks_host  = var.enable_k8s_providers ? data.aws_eks_cluster.this[0].endpoint : "https://example.invalid"
  eks_ca    = var.enable_k8s_providers ? base64decode(data.aws_eks_cluster.this[0].certificate_authority[0].data) : ""
  eks_token = var.enable_k8s_providers ? data.aws_eks_cluster_auth.this[0].token : ""
}

provider "kubernetes" {
  host                   = local.eks_host
  cluster_ca_certificate = local.eks_ca
  token                  = local.eks_token
}

provider "helm" {
  kubernetes {
    host                   = local.eks_host
    cluster_ca_certificate = local.eks_ca
    token                  = local.eks_token
  }
}

data "aws_iam_policy" "alb_controller" {
  name = "AWSLoadBalancerControllerIAMPolicy"
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  depends_on = [module.alb_controller]
  role       = module.alb_controller.iam_role_name
  policy_arn = data.aws_iam_policy.alb_controller.arn
}
