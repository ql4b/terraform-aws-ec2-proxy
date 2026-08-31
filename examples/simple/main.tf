# Simple example — deploys a proxy with all defaults.
# Ingress is automatically restricted to the caller's public IP.

provider "aws" {
  region = "us-east-1"
}

module "proxy" {
  source = "github.com/ql4b/terraform-aws-ec2-proxy?ref=v2.4.0"

  namespace = "myorg"
  name      = "proxy"
}

output "proxy_url" {
  value = module.proxy.proxy_url
}

output "public_ip" {
  value = module.proxy.public_ip
}
