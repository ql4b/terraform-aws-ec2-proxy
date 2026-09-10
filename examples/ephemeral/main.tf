# Ephemeral (disposable) example — proxy self-terminates after a TTL.
#
# With ttl_hours set, the module also creates the scale-to-zero Lambda +
# EventBridge rule: the instance self-terminates after 2 hours, the Lambda
# sets the ASG desired capacity to 0, and Terraform sees no drift.
#
# To hand out a fresh proxy (new IP) later without a re-apply:
#   aws autoscaling set-desired-capacity \
#     --auto-scaling-group-name "$(terraform output -raw asg_name)" \
#     --desired-capacity 1

provider "aws" {
  region = "us-east-1"
}

module "proxy" {
  source = "../../"

  namespace = "myorg"
  name      = "proxy"

  # Instance self-terminates after 2 hours; ASG scales to zero (no drift).
  ttl_hours = 2
}

output "asg_name" {
  description = "Scale this ASG 0<->1 to stop/start the proxy."
  value       = module.proxy.asg_name
}
