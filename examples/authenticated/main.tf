# Authenticated example — proxy requires HTTP basic auth credentials.

provider "aws" {
  region = "us-east-1"
}

variable "proxy_username" {
  description = "Username for the proxy"
  type        = string
  sensitive   = true
}

variable "proxy_password" {
  description = "Password for the proxy"
  type        = string
  sensitive   = true
}

module "proxy" {
  source = "github.com/ql4b/terraform-aws-ec2-proxy?ref=v2.4.0"

  namespace = "myorg"
  name      = "proxy"

  proxy_username = var.proxy_username
  proxy_password = var.proxy_password
}

output "proxy_url" {
  description = "Proxy URL with embedded credentials — use as HTTP_PROXY"
  value       = module.proxy.proxy_url
  sensitive   = true
}

output "public_ip" {
  value = module.proxy.public_ip
}
