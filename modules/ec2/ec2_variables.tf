variable "ami_id" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "security_group_ids" {
  type = list(string)
}
variable "instance_name" {}
variable "associate_public_ip" {
  type    = bool
  default = false
}
variable "key_name" {
  type    = string
  default = ""
}

variable "user_data" {
  type    = string
  default = ""
}

variable "iam_instance_profile_name" {
  type    = string
  default = ""
}
