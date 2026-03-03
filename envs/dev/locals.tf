locals {
  weather_ingress_host   = var.weather_ingress_host != "" ? var.weather_ingress_host : "weather.${var.domain_name}"
  solitaire_ingress_host = var.solitaire_ingress_host != "" ? var.solitaire_ingress_host : "solitaire.${var.domain_name}"
  effective_vpn_cidrs    = length(var.vpn_allowed_cidrs) > 0 ? var.vpn_allowed_cidrs : [var.allowed_client_cidr]
  effective_alb_ingress_cidrs = distinct(concat(
    local.effective_vpn_cidrs,
    [var.vpc_cidr]
  ))
}
