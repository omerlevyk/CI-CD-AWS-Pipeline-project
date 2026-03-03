module "vpc" {
  source = "../vpc"

  vpc_cidr = var.vpc_cidr
}

module "security_groups" {
  source = "../security_groups"

  vpc_id            = module.vpc.vpc_id
  alb_ingress_cidrs = var.alb_ingress_cidrs
}

data "aws_iam_policy_document" "gitlab_ssm_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "gitlab_ssm_role" {
  name               = "${var.cluster_name}-gitlab-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.gitlab_ssm_assume_role.json
}

resource "aws_iam_role_policy_attachment" "gitlab_ssm_core" {
  role       = aws_iam_role.gitlab_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "gitlab_ssm_profile" {
  name = "${var.cluster_name}-gitlab-ssm-profile"
  role = aws_iam_role.gitlab_ssm_role.name
}

module "gitlab" {
  source = "../ec2"

  ami_id                    = var.gitlab_ami
  instance_type             = var.gitlab_instance_type
  subnet_id                 = module.vpc.private_subnet_ids[0]
  security_group_ids        = [module.security_groups.private_instances_sg_id]
  instance_name             = "gitlab-server"
  key_name                  = var.key_name
  iam_instance_profile_name = aws_iam_instance_profile.gitlab_ssm_profile.name
  user_data                 = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee -a /var/log/gitlab-bootstrap.log) 2>&1
    export DEBIAN_FRONTEND=noninteractive

    retry() {
      local n=0
      local max=5
      local delay=20
      until "$@"; do
        n=$((n+1))
        if [ "$n" -ge "$max" ]; then
          return 1
        fi
        sleep "$delay"
      done
    }

    if ! swapon --show | grep -q '/swapfile'; then
      fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    retry apt-get update -y
    retry apt-get install -y curl ca-certificates tzdata perl

    if ! command -v gitlab-ctl >/dev/null 2>&1; then
      retry bash -lc "curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash"
      retry bash -lc "EXTERNAL_URL='http://gitlab.${var.domain_name}' apt-get install -y gitlab-ce"
    fi

    gitlab-ctl reconfigure
    gitlab-ctl restart
    gitlab-ctl status
  EOT
}

module "jenkins_controller" {
  source = "../ec2"

  ami_id             = var.jenkins_controller_ami
  instance_type      = var.jenkins_controller_instance_type
  subnet_id          = module.vpc.private_subnet_ids[0]
  security_group_ids = [module.security_groups.private_instances_sg_id]
  instance_name      = "jenkins-controller"
  key_name           = var.key_name
}

module "jenkins_agent" {
  count  = var.create_jenkins_agent ? 1 : 0
  source = "../ec2"

  ami_id             = var.jenkins_agent_ami
  instance_type      = var.jenkins_agent_instance_type
  subnet_id          = module.vpc.private_subnet_ids[0]
  security_group_ids = [module.security_groups.private_instances_sg_id]
  instance_name      = "jenkins-agent"
  key_name           = var.key_name
}

module "eks" {
  source = "../eks"

  cluster_name                         = var.cluster_name
  vpc_id                               = module.vpc.vpc_id
  private_subnet_ids                   = module.vpc.private_subnet_ids
  alb_sg_id                            = module.security_groups.alb_sg_id
  weather_node_port                    = var.weather_node_port
  cluster_endpoint_public_access_cidrs = var.eks_api_ingress_cidrs
}
