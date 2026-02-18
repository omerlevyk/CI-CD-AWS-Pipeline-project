data "aws_caller_identity" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  enable_irsa = true

  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    aws-efs-csi-driver = {
      most_recent = true
    }
  }

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  create_kms_key            = false
  cluster_encryption_config = {}

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 2
      desired_size   = 2
      iam_role_additional_policies = {
        ebs_csi = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        efs_csi = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
      }
    }
  }

  node_security_group_additional_rules = {
    ingress_weather_nodeport_from_alb = {
      type                     = "ingress"
      protocol                 = "tcp"
      from_port                = var.weather_node_port
      to_port                  = var.weather_node_port
      source_security_group_id = var.alb_sg_id
      description              = "Allow ALB traffic to weather app NodePort"
    }
  }

  access_entries = {
    terraform = {
      principal_arn = data.aws_caller_identity.current.arn

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}
