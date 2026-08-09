data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
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
  name   = module.this.id
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = var.proxy_port
    to_port     = var.proxy_port
    protocol    = "tcp"
    cidr_blocks = local.effective_cidrs
  }

  egress {
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
  user_data     = <<-EOF
#!/bin/bash
dnf install -y squid
printf 'http_port ${var.proxy_port}\nhttp_access allow all\nvia off\nforwarded_for delete\n' > /etc/squid/squid.conf
systemctl enable --now squid
EOF
  instance_tags = merge(module.this.tags, { Name = module.this.id })
}

resource "aws_spot_instance_request" "proxy" {
  count = var.spot ? 1 : 0

  ami                    = data.aws_ssm_parameter.ami.value
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.proxy.id]
  iam_instance_profile   = aws_iam_instance_profile.proxy.name
  user_data              = local.user_data

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
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

  ami                    = data.aws_ssm_parameter.ami.value
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.proxy.id]
  iam_instance_profile   = aws_iam_instance_profile.proxy.name
  user_data              = local.user_data

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = local.instance_tags
}
