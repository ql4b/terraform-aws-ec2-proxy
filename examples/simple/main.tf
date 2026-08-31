# Simple example — deploys a proxy with all defaults.
# Ingress is automatically restricted to the caller's public IP.

provider "aws" {
  region = "us-east-1"
}

module "proxy" {
  source = "../../"

  namespace = "myorg"
  name      = "proxy"
}

output "proxy_url" {
  value = module.proxy.proxy_url
}

output "public_ip" {
  value = module.proxy.public_ip
}
