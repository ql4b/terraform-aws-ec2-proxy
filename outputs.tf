locals {
  public_ip   = var.spot ? aws_spot_instance_request.proxy[0].public_ip : aws_instance.proxy[0].public_ip
  instance_id = var.spot ? aws_spot_instance_request.proxy[0].spot_instance_id : aws_instance.proxy[0].id
}

output "public_ip" {
  value = local.public_ip
}

output "instance_id" {
  value = local.instance_id
}

output "proxy_url" {
  value = "http://${local.public_ip}:${var.proxy_port}"
}

output "instance_type" {
  value = var.spot ? aws_spot_instance_request.proxy[0].instance_type : aws_instance.proxy[0].instance_type
}

output "is_spot" {
  value = var.spot
}

output "region" {
  value = data.aws_region.current.region
}
