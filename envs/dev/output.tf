output "cluster_name" {
  value = module.infrastructure.cluster_name
}

output "weather_service_name" {
  value = "weather-service"
}

output "weather_node_port" {
  value = var.weather_node_port
}

output "solitaire_node_port" {
  value = var.solitaire_node_port
}

output "ci_alb_dns" {
  value = module.alb.alb_dns
}

output "weather_ingress_host" {
  value = local.weather_ingress_host
}

output "solitaire_ingress_host" {
  value = local.solitaire_ingress_host
}

output "alb_controller_role_arn" {
  value = module.alb_controller.iam_role_arn
}

output "gitlab_dns_record" {
  value = module.dns_gitlab.hostname
}

output "jenkins_dns_record" {
  value = module.dns_jenkins.hostname
}
