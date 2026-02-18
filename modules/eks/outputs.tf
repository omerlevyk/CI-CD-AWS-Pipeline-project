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

output "eks_managed_node_group_asg_names" {
  value = module.eks.eks_managed_node_groups_autoscaling_group_names
}

output "eks_managed_node_group_asg_name_map" {
  value = {
    default = module.eks.eks_managed_node_groups_autoscaling_group_names[0]
  }
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}
