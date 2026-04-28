terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

resource "cloudflare_record" "this" {
  zone_id = var.zone_id
  name    = var.subdomain
  type    = "CNAME"
  content = var.alb_hostname
  proxied = var.proxied
}
