# Authenticated example — proxy requires HTTP basic auth credentials.

provider "aws" {
  region = "us-east-1"
}

variable "proxy_username" {
  description = "Username for the proxy"
  type        = string
  sensitive   = true
}

variable "proxy_password" {
  description = "Password for the proxy"
  type        = string
  sensitive   = true
}

module "proxy" {
  source = "../../"

  namespace = "myorg"
  name      = "proxy"

  proxy_username = var.proxy_username
  proxy_password = var.proxy_password
}

output "asg_name" {
  value = module.proxy.asg_name
}

# Auth credentials are baked into the launch template user_data. Resolve the
# running instance's IP live by tag, then use:
#   http://<username>:<password>@<ip>:8888
