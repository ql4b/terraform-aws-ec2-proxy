# terraform-aws-ec2-proxy

> Terraform module for a disposable EC2 proxy instance for IP diversification

## Usage

```hcl
module "proxy" {
  source = "github.com/ql4b/terraform-aws-ec2-proxy"

  namespace = "cloudless"
  name      = "proxy"
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `namespace` | Resource namespace | `string` | `null` |
| `name` | Resource name | `string` | `null` |
| `instance_type` | EC2 instance type | `string` | `t4g.nano` |
| `proxy_port` | Proxy listening port | `number` | `8888` |
| `allowed_cidrs` | CIDRs allowed to use the proxy | `list(string)` | `["0.0.0.0/0"]` |
| `spot` | Use spot instance | `bool` | `true` |

## Outputs

| Name | Description |
|------|-------------|
| `public_ip` | Instance public IP |
| `instance_id` | Instance ID |
| `proxy_url` | Full proxy URL (`http://<ip>:<port>`) |

## Design

- AL2023 arm64 AMI via SSM parameter (always latest)
- Squid HTTP proxy — available in AL2023 default repos
- Default VPC, dedicated security group
- IAM role with `AmazonSSMManagedInstanceCore` — no SSH, no key pairs
- `spot = true` uses `aws_spot_instance_request`, `spot = false` uses `aws_instance`
