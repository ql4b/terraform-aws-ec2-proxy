# Restricted example — explicit CIDRs, on-demand instance, custom port.

provider "aws" {
  region = "eu-west-1"
}

module "proxy" {
  source = "../../"

  namespace = "myorg"
  stage     = "dev"
  name      = "proxy"

  # Only allow traffic from the office and VPN
  allowed_cidrs = ["203.0.113.0/24", "198.51.100.10/32"]

  # Use on-demand for longer-running workloads
  spot = false

  # Custom port
  proxy_port = 3128

  # Larger instance for heavier traffic
  instance_type = "t4g.micro"
}

output "proxy_url" {
  value = module.proxy.proxy_url
}

output "instance_id" {
  value = module.proxy.instance_id
}

output "is_spot" {
  value = module.proxy.is_spot
}
