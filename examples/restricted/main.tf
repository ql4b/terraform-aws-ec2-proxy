# Restricted example — explicit CIDRs and a custom port.

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

  # Custom port
  proxy_port = 3128

  # Larger instance for heavier traffic
  instance_type = "t4g.micro"
}

output "asg_name" {
  value = module.proxy.asg_name
}

output "launch_template_id" {
  value = module.proxy.launch_template_id
}
