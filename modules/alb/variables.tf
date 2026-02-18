variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "certificate_arn" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "gitlab_instance_id" {
  type = string
}

variable "jenkins_instance_id" {
  type = string
}

variable "eks_node_group_asg_name_map" {
  type = map(string)
}

variable "weather_node_port" {
  type    = number
  default = 30080
}
