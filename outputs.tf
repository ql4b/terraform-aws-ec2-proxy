locals {
  public_ip   = var.spot ? aws_spot_instance_request.proxy[0].public_ip : aws_instance.proxy[0].public_ip
  instance_id = var.spot ? aws_spot_instance_request.proxy[0].spot_instance_id : aws_instance.proxy[0].id
}

output "public_ip" {
  description = "Public IP address of the proxy instance"
  value       = local.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = local.instance_id
}

output "proxy_url" {
  description = "Full proxy URL ready for HTTP_PROXY usage (includes credentials if auth is enabled)"
  value       = local.auth_enabled ? "http://${var.proxy_username}:${var.proxy_password}@${local.public_ip}:${var.proxy_port}" : "http://${local.public_ip}:${var.proxy_port}"
  sensitive   = true
}

output "instance_type" {
  description = "Instance type of the proxy"
  value       = var.spot ? aws_spot_instance_request.proxy[0].instance_type : aws_instance.proxy[0].instance_type
}

output "is_spot" {
  description = "Whether the instance is a spot instance"
  value       = var.spot
}

output "region" {
  description = "AWS region the proxy is deployed in"
  value       = data.aws_region.current.region
}
