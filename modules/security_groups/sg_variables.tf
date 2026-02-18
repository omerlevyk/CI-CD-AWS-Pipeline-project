variable "vpc_id" {
  type = string
}

variable "alb_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
