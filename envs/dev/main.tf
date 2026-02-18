module "infrastructure" {
  source = "../../modules/infra"

  vpc_cidr               = var.vpc_cidr
  cluster_name           = var.cluster_name
  domain_name            = var.domain_name
  gitlab_ami             = var.gitlab_ami
  gitlab_instance_type   = var.gitlab_instance_type
  jenkins_controller_ami = var.jenkins_controller_ami
  jenkins_agent_ami      = var.jenkins_agent_ami
  key_name               = var.key_name
  weather_node_port      = var.weather_node_port
  alb_ingress_cidrs      = [var.allowed_client_cidr]
}

module "alb" {
  source = "../../modules/alb"

  vpc_id                      = module.infrastructure.vpc_id
  public_subnet_ids           = module.infrastructure.public_subnet_ids
  alb_sg_id                   = module.infrastructure.alb_sg_id
  certificate_arn             = var.certificate_arn
  domain_name                 = var.domain_name
  gitlab_instance_id          = module.infrastructure.gitlab_instance_id
  jenkins_instance_id         = module.infrastructure.jenkins_instance_id
  eks_node_group_asg_name_map = module.infrastructure.eks_node_group_asg_name_map
  weather_node_port           = var.weather_node_port
}

module "alb_controller" {
  source = "../../modules/alb_controller"

  cluster_name      = module.infrastructure.cluster_name
  region            = var.aws_region
  vpc_id            = module.infrastructure.vpc_id
  oidc_provider_arn = module.infrastructure.oidc_provider_arn
  oidc_provider_url = module.infrastructure.cluster_oidc_issuer_url
}

module "dns_gitlab" {
  source = "../../modules/dns"

  zone_id      = var.cloudflare_zone_id
  subdomain    = "gitlab"
  alb_hostname = module.alb.alb_dns
  proxied      = false
}

module "dns_jenkins" {
  source = "../../modules/dns"

  zone_id      = var.cloudflare_zone_id
  subdomain    = "jenkins"
  alb_hostname = module.alb.alb_dns
  proxied      = false
}
