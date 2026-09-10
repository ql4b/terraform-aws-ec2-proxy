locals {
  standalone_ip = var.use_asg ? null : (
    var.spot ? aws_spot_instance_request.proxy[0].public_ip : aws_instance.proxy[0].public_ip
  )
  standalone_id = var.use_asg ? null : (
    var.spot ? aws_spot_instance_request.proxy[0].spot_instance_id : aws_instance.proxy[0].id
  )

  # In ASG mode the running instance is dynamic (and may be absent when the
  # ASG is scaled to zero). Resolve the current instance, if any, by tag.
  asg_instance_ids = var.use_asg ? data.aws_instances.proxy[0].ids : []
  asg_instance_ips = var.use_asg ? data.aws_instances.proxy[0].public_ips : []

  public_ip = var.use_asg ? (
    length(local.asg_instance_ips) > 0 ? local.asg_instance_ips[0] : null
  ) : local.standalone_ip

  instance_id = var.use_asg ? (
    length(local.asg_instance_ids) > 0 ? local.asg_instance_ids[0] : null
  ) : local.standalone_id
}

# Best-effort lookup of the ASG's current running instance (ASG mode only).
# Filtered by the module's ownership tag. Returns empty when scaled to zero.
data "aws_instances" "proxy" {
  count = var.use_asg ? 1 : 0

  instance_tags = {
    "proxy:managed-by" = module.this.id
  }

  instance_state_names = ["pending", "running"]
}

output "public_ip" {
  description = "Public IP address of the proxy instance. Null in ASG mode when the group is scaled to zero."
  value       = local.public_ip
}

output "instance_id" {
  description = "EC2 instance ID. Null in ASG mode when the group is scaled to zero."
  value       = local.instance_id
}

output "proxy_url" {
  description = "Full proxy URL ready for HTTP_PROXY usage (includes credentials if auth is enabled). Null in ASG mode when the group is scaled to zero."
  value = local.public_ip == null ? null : (
    local.auth_enabled ? "http://${var.proxy_username}:${var.proxy_password}@${local.public_ip}:${var.proxy_port}" : "http://${local.public_ip}:${var.proxy_port}"
  )
  sensitive = true
}

output "instance_type" {
  description = "Instance type of the proxy"
  value       = var.instance_type
}

output "is_spot" {
  description = "Whether the instance is a spot instance"
  value       = var.spot
}

output "region" {
  description = "AWS region the proxy is deployed in"
  value       = data.aws_region.current.region
}

output "ttl_hours" {
  description = "Hours after launch before the instance self-terminates, or null if auto-termination is disabled."
  value       = var.ttl_hours
}

output "asg_name" {
  description = "Name of the Auto Scaling Group managing the proxy, or null when use_asg is false."
  value       = var.use_asg ? aws_autoscaling_group.proxy[0].name : null
}
