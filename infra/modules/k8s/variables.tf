variable "app_name" {
  type    = string
  default = "weather-app"
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "weather_image_repository" {
  type = string
}

variable "weather_image_tag" {
  type    = string
  default = "v1.0.0"
}

variable "weather_replicas" {
  type    = number
  default = 4
}

variable "weather_container_port" {
  type    = number
  default = 5000
}

variable "weather_service_port" {
  type    = number
  default = 80
}

variable "weather_node_port" {
  type    = number
  default = 32300
}

variable "weather_bg_color_configmap" {
  type    = string
  default = "bg-color-blue"
}

variable "weather_history_mount_path" {
  type    = string
  default = "/app/history"
}

variable "solitaire_image_repository" {
  type    = string
  default = "chimenesjr/solitaire"
}

variable "solitaire_image_tag" {
  type    = string
  default = "nginx"
}

variable "solitaire_replicas" {
  type    = number
  default = 4
}

variable "solitaire_container_port" {
  type    = number
  default = 80
}

variable "solitaire_service_port" {
  type    = number
  default = 80
}

variable "solitaire_node_port" {
  type    = number
  default = 32400
}

variable "storage_class_name" {
  type    = string
  default = "weather-efs-sc-v1"
}

variable "storage_class_is_default" {
  type    = bool
  default = false
}

variable "storage_volume_type" {
  type    = string
  default = "gp2"
}

variable "efs_file_system_id" {
  type = string
}

variable "storage_size" {
  type    = string
  default = "5Gi"
}

variable "ingress_enabled" {
  type    = bool
  default = false
}

variable "ingress_class_name" {
  type    = string
  default = "alb"
}

variable "ingress_host" {
  type    = string
  default = ""
}

variable "solitaire_ingress_host" {
  type    = string
  default = ""
}

variable "ingress_certificate_arn" {
  type    = string
  default = ""
}
