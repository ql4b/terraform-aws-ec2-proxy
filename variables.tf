variable "instance_type" {
  type    = string
  default = "t4g.nano"
}

variable "proxy_port" {
  type    = number
  default = 8888
}

variable "allowed_cidrs" {
  description = "List of CIDRs allowed to reach the proxy. When empty (default), the module auto-detects the caller's public IP and restricts access to that single address."
  type        = list(string)
  default     = []
}

variable "spot" {
  type    = bool
  default = true
}
