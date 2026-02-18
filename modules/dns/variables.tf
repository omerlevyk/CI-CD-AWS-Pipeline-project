variable "zone_id" {
  type = string
}

variable "subdomain" {
  type = string
}

variable "alb_hostname" {
  type = string
}

variable "proxied" {
  type    = bool
  default = true
}
