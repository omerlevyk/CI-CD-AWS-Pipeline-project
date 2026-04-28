variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "cluster_name" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "gitlab_ami" {
  type        = string
  description = "Golden AMI ID for the GitLab EC2 instance"
}

variable "jenkins_controller_ami" {
  type        = string
  description = "Golden AMI ID for the Jenkins controller EC2 instance"
}

variable "jenkins_agent_ami" {
  type        = string
  description = "Golden AMI ID for the Jenkins agent EC2 instance"
}

variable "gitlab_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "jenkins_controller_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "jenkins_agent_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "create_jenkins_agent" {
  type    = bool
  default = true
}

variable "key_name" {
  type    = string
  default = ""
}

variable "weather_node_port" {
  type    = number
  default = 30080
}

variable "alb_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "eks_api_ingress_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to access the public EKS API endpoint."
  default     = ["0.0.0.0/0"]
}
