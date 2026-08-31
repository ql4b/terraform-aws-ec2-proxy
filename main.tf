data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_vpc" "default" {
  count   = var.vpc_id == null ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.subnet_id == null ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

locals {
  vpc_id    = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id
  subnet_id = var.subnet_id != null ? var.subnet_id : data.aws_subnets.default[0].ids[0]
}

# get current region
data "aws_region" "current" {}

# Auto-detect caller's public IP when allowed_cidrs is not explicitly set
data "http" "caller_ip" {
  count = length(var.allowed_cidrs) == 0 ? 1 : 0
  url   = "https://checkip.amazonaws.com"
}

locals {
  effective_cidrs = length(var.allowed_cidrs) > 0 ? var.allowed_cidrs : ["${trimspace(data.http.caller_ip[0].response_body)}/32"]
}

resource "aws_security_group" "proxy" {
  name        = module.this.id
  description = "Allow inbound proxy traffic and all outbound for Squid forward proxy"
  vpc_id      = local.vpc_id

  ingress {
    description = "Proxy port from allowed CIDRs"
    from_port   = var.proxy_port
    to_port     = var.proxy_port
    protocol    = "tcp"
    cidr_blocks = local.effective_cidrs
  }

  egress {
    description = "Allow all outbound traffic for proxy forwarding"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = module.this.tags
}

resource "aws_iam_instance_profile" "proxy" {
  name = module.this.id
  role = aws_iam_role.proxy.name
}

resource "aws_iam_role" "proxy" {
  name = module.this.id

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = module.this.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.proxy.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

locals {
  ttl_shutdown = var.ttl_hours != null ? "\nshutdown -h +${var.ttl_hours * 60}\n" : ""
  auth_enabled = var.proxy_username != null && var.proxy_password != null

  squid_conf_noauth = <<-CONF
http_port ${var.proxy_port}
http_access allow all
via off
forwarded_for delete
CONF

  squid_conf_auth = <<-CONF
http_port ${var.proxy_port}
auth_param basic program /usr/lib64/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all
via off
forwarded_for delete
CONF

  squid_conf = local.auth_enabled ? local.squid_conf_auth : local.squid_conf_noauth

  htpasswd_cmd = local.auth_enabled ? "dnf install -y httpd-tools\nhtpasswd -cb /etc/squid/passwd '${var.proxy_username}' '${var.proxy_password}'\n" : ""

  user_data = <<-EOF
#!/bin/bash
dnf install -y squid
${local.htpasswd_cmd}cat > /etc/squid/squid.conf << 'SQUIDEOF'
${local.squid_conf}SQUIDEOF
systemctl enable --now squid${local.ttl_shutdown}
EOF

  instance_tags = merge(module.this.tags, { Name = module.this.id })
}

resource "aws_spot_instance_request" "proxy" {
  count = var.spot ? 1 : 0

  ami                                  = data.aws_ssm_parameter.ami.value
  instance_type                        = var.instance_type
  subnet_id                            = local.subnet_id
  associate_public_ip_address          = true #checkov:skip=CKV_AWS_88:Public IP required — this is an internet-facing forward proxy
  vpc_security_group_ids               = [aws_security_group.proxy.id]
  iam_instance_profile                 = aws_iam_instance_profile.proxy.name
  user_data                            = local.user_data
  instance_initiated_shutdown_behavior = var.ttl_hours != null ? "terminate" : "stop"

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted = true
  }

  wait_for_fulfillment = true
  spot_type            = "one-time"

  tags = local.instance_tags
}

resource "aws_ec2_tag" "proxy" {
  for_each    = var.spot ? local.instance_tags : {}
  resource_id = aws_spot_instance_request.proxy[0].spot_instance_id
  key         = each.key
  value       = each.value
}

resource "aws_instance" "proxy" {
  count = var.spot ? 0 : 1

  ami                                  = data.aws_ssm_parameter.ami.value
  instance_type                        = var.instance_type
  subnet_id                            = local.subnet_id
  associate_public_ip_address          = true #checkov:skip=CKV_AWS_88:Public IP required — this is an internet-facing forward proxy
  vpc_security_group_ids               = [aws_security_group.proxy.id]
  iam_instance_profile                 = aws_iam_instance_profile.proxy.name
  user_data                            = local.user_data
  instance_initiated_shutdown_behavior = var.ttl_hours != null ? "terminate" : "stop"

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted = true
  }

  tags = local.instance_tags
}
