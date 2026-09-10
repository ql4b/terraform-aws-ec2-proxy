variable "vpc_id" {
  description = "ID of the VPC to deploy into. When null (default), the module uses the region's default VPC."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "ID of the subnet to launch the instance in. When null (default), the module picks the first subnet in the selected VPC. Must belong to the VPC specified by vpc_id (or the default VPC when vpc_id is null)."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type for the proxy."
  type        = string
  default     = "t4g.nano"
}

variable "proxy_port" {
  description = "TCP port Squid listens on."
  type        = number
  default     = 8888
}

variable "allowed_cidrs" {
  description = "List of CIDRs allowed to reach the proxy. When empty (default), the module auto-detects the caller's public IP and restricts access to that single address."
  type        = list(string)
  default     = []
}

variable "spot" {
  description = "Use a spot instance for cost savings. Set to false for on-demand."
  type        = bool
  default     = true
}

variable "ttl_hours" {
  description = "Hours after launch before the instance self-terminates. Set to null (default) to disable auto-termination."
  type        = number
  default     = null
}

variable "proxy_username" {
  description = "Username for Squid basic authentication. Both proxy_username and proxy_password must be set to enable auth."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxy_password" {
  description = "Password for Squid basic authentication. Both proxy_username and proxy_password must be set to enable auth."
  type        = string
  default     = null
  sensitive   = true
}


variable "use_asg" {
  description = "Experimental: manage the proxy via an Auto Scaling Group instead of a standalone instance. When true, the module creates an ASG (backed by the shared launch template) plus an EventBridge rule and Lambda that set the ASG's desired capacity to 0 when a proxy instance begins shutting down (e.g. via ttl_hours). This keeps Terraform state free of drift while the instance count is managed out-of-band. Mutually exclusive with the standalone aws_instance/aws_spot_instance_request path."
  type        = bool
  default     = false
}
