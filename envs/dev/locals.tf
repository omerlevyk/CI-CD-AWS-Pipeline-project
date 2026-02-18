locals {
  weather_ingress_host   = var.weather_ingress_host != "" ? var.weather_ingress_host : "weather.${var.domain_name}"
  solitaire_ingress_host = var.solitaire_ingress_host != "" ? var.solitaire_ingress_host : "solitaire.${var.domain_name}"
}
