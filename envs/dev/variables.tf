variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token"
}

variable "cloudflare_zone_id" {
  type = string
}

variable "certificate_arn" {
  type = string
}

variable "domain_name" {
  type    = string
  default = "omerlevy03.com"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "cluster_name" {
  type    = string
  default = "weather-app-eks"
}

variable "gitlab_ami" {
  type = string
}

variable "gitlab_instance_type" {
  type    = string
  default = "t3.large"
}

variable "jenkins_controller_ami" {
  type = string
}

variable "jenkins_agent_ami" {
  type = string
}

variable "key_name" {
  type = string
}

variable "weather_app_image_repository" {
  type    = string
  default = "omerlevyk/weather_app-app"
}

variable "weather_app_image_tag" {
  type    = string
  default = "v1.0.0"
}

variable "weather_app_replicas" {
  type    = number
  default = 4
}

variable "weather_app_container_port" {
  type    = number
  default = 5000
}

variable "weather_app_service_port" {
  type    = number
  default = 80
}

variable "weather_node_port" {
  type    = number
  default = 32300
}

variable "solitaire_node_port" {
  type    = number
  default = 32400
}

variable "weather_ingress_enabled" {
  type    = bool
  default = true
}

variable "weather_ingress_host" {
  type    = string
  default = ""
}

variable "solitaire_ingress_host" {
  type    = string
  default = ""
}

variable "allowed_client_cidr" {
  type        = string
  description = "Public client CIDR allowed to access the shared ALB (for example 203.0.113.10/32)"
}

variable "manage_alb_controller_with_terraform" {
  type    = bool
  default = true
}
