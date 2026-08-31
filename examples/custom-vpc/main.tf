# Custom VPC example — deploys a proxy into an existing VPC and subnet
# instead of relying on the region's default VPC.
#
# Usage:
#   terraform apply -var="vpc_id=vpc-abc123" -var="subnet_id=subnet-def456"

variable "vpc_id" {
  description = "VPC to deploy the proxy into."
  type        = string
}

variable "subnet_id" {
  description = "Public subnet for the proxy instance (must have an internet gateway route)."
  type        = string
}

provider "aws" {
  region = "eu-south-1"
}

module "proxy" {
  source = "github.com/ql4b/terraform-aws-ec2-proxy?ref=v2.4.0"

  namespace = "myorg"
  name      = "proxy"

  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id
  spot      = false
}

output "proxy_url" {
  value     = module.proxy.proxy_url
  sensitive = true
}

output "public_ip" {
  value = module.proxy.public_ip
}
