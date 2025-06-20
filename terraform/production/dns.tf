provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "frontend" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  value   = vercel_deployment.this.domains[0]
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

