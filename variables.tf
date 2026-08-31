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
