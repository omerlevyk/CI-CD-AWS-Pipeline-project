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

variable "gitlab_instance_id" {
  type = string
}

variable "jenkins_instance_id" {
  type = string
}

variable "domain_name" {
  type = string
}
