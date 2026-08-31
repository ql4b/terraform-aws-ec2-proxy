# Ephemeral example — proxy self-terminates after a TTL.
# Useful for one-off tasks where you don't want to remember to destroy.

provider "aws" {
  region = "us-east-1"
}

module "proxy" {
  source = "../../"

  namespace = "myorg"
  name      = "proxy"

  # Instance will self-terminate after 2 hours
  ttl_hours = 2
}

output "proxy_url" {
  description = "Proxy URL — instance will auto-terminate after 2 hours"
  value       = module.proxy.proxy_url
  sensitive   = true
}

output "public_ip" {
  value = module.proxy.public_ip
}
