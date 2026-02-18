output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "alb_sg_id" {
  value = module.security_groups.alb_sg_id
}

output "gitlab_instance_id" {
  value = module.gitlab.instance_id
}

output "jenkins_instance_id" {
  value = module.jenkins_controller.instance_id
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "eks_node_group_asg_names" {
  value = module.eks.eks_managed_node_group_asg_names
}

output "eks_node_group_asg_name_map" {
  value = module.eks.eks_managed_node_group_asg_name_map
}

output "efs_file_system_id" {
  value = aws_efs_file_system.weather_history.id
}
