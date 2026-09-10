output "asg_name" {
  description = "Name of the Auto Scaling Group managing the proxy. Scale it to 1 to hand out a proxy (new public IP) or 0 to stop cost: aws autoscaling set-desired-capacity --auto-scaling-group-name <name> --desired-capacity <0|1>"
  value       = aws_autoscaling_group.proxy.name
}

output "launch_template_id" {
  description = "ID of the launch template backing the proxy ASG."
  value       = aws_launch_template.proxy.id
}

output "instance_type" {
  description = "Instance type of the proxy."
  value       = var.instance_type
}

output "region" {
  description = "AWS region the proxy is deployed in."
  value       = data.aws_region.current.region
}

output "ttl_hours" {
  description = "Hours after launch before the instance self-terminates, or null if auto-termination is disabled."
  value       = var.ttl_hours
}

# NOTE: The running instance is managed by the ASG and changes out-of-band
# (TTL shutdown, scale-to-zero, scale-up), so its IP/ID are intentionally NOT
# Terraform outputs — a Terraform value would be stale the moment the instance
# recycles. Resolve the live proxy from EC2 by the "proxy:managed-by" tag
# instead (see the wrapper's `proxy url` / `proxy status` helpers).
