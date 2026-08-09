variable "instance_type" {
  type    = string
  default = "t4g.nano"
}

variable "proxy_port" {
  type    = number
  default = 8888
}

variable "allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "spot" {
  type    = bool
  default = true
}
