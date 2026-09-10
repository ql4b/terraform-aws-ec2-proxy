# Simple example — deploys a proxy with all defaults (always-on ASG).
# Ingress is automatically restricted to the caller's public IP.

provider "aws" {
  region = "us-east-1"
}

module "proxy" {
  source = "../../"

  namespace = "myorg"
  name      = "proxy"
}

output "asg_name" {
  value = module.proxy.asg_name
}

# The running instance is dynamic (ASG-managed), so its IP is not a Terraform
# output. Resolve it live by the proxy:managed-by tag:
#   aws ec2 describe-instances \
#     --filters "Name=tag:proxy:managed-by,Values=myorg-proxy" \
#               "Name=instance-state-name,Values=running" \
#     --query 'Reservations[].Instances[].PublicIpAddress' --output text
