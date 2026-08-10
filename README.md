# terraform-aws-ec2-proxy

Disposable EC2-based HTTP proxy for IP diversification. Deploy a Squid forward proxy with a fresh public IP on every `terraform apply` cycle.

## Use Cases

- Rotate source IPs for web scraping or API testing
- Validate geo-restrictions or firewall rules from a cloud IP
- Avoid rate limits by cycling proxy instances
- One-command throwaway proxy with zero residual cost

## Prerequisites

- Terraform >= 1.0
- AWS account with a **default VPC** (present in all accounts unless manually deleted)
- AWS credentials configured (`aws configure`, env vars, or IAM role)
- No pre-existing infrastructure required

## Quick Start

```hcl
module "proxy" {
  source = "github.com/ql4b/terraform-aws-ec2-proxy?ref=v2.0.0"

  namespace = "myorg"
  name      = "proxy"
}

output "proxy_url" {
  value     = module.proxy.proxy_url
  sensitive = true
}
```

```bash
terraform init
terraform apply

# Use the proxy
export HTTP_PROXY=$(terraform output -raw proxy_url)
curl http://httpbin.org/ip

# Done — destroy to stop billing
terraform destroy
```

> **Tip:** Always pin to a specific release tag (e.g. `?ref=v2.0.0`). Browse
> available versions on the [Releases](https://github.com/ql4b/terraform-aws-ec2-proxy/releases) page.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ Default VPC                                         │
│                                                     │
│  ┌──────────────────────────────────────┐           │
│  │ EC2 (spot or on-demand)              │           │
│  │ Amazon Linux 2023 · arm64 · t4g.nano │           │
│  │                                      │           │
│  │  ┌───────────┐                       │           │
│  │  │   Squid   │ ← port 8888 (HTTP)   │           │
│  │  └───────────┘                       │           │
│  │                                      │           │
│  │  IAM Role: AmazonSSMManagedInstance  │           │
│  │  (no SSH key, no inbound port 22)    │           │
│  └──────────────────────────────────────┘           │
│                                                     │
│  Security Group:                                    │
│    ingress: caller IP (auto) → proxy_port/tcp       │
│    egress:  0.0.0.0/0 → all                         │
└─────────────────────────────────────────────────────┘
```

## Features

| Feature | Details |
|---------|---------|
| **Spot instances** | Default `spot = true` for ~70% cost savings |
| **ARM64 (Graviton)** | Best price-performance at t4g.nano |
| **Auto-detected ingress** | When `allowed_cidrs` is empty, restricts to caller's IP/32 |
| **Basic auth** | Optional `proxy_username` + `proxy_password` for Squid authentication |
| **TTL auto-terminate** | `ttl_hours` triggers self-termination — no forgotten instances |
| **IMDSv2 enforced** | Mitigates SSRF credential theft |
| **Encrypted EBS** | Root volume encryption enabled by default |
| **SSM access** | Debug via `aws ssm start-session` — no SSH keys needed |
| **Privacy headers** | `via off`, `forwarded_for delete` hides client identity |

## Examples

- [`examples/simple`](examples/simple) — All defaults, caller IP auto-detected
- [`examples/restricted`](examples/restricted) — Explicit CIDRs, on-demand instance, custom port

### With Authentication

```hcl
module "proxy" {
  source = "github.com/ql4b/terraform-aws-ec2-proxy?ref=v2.0.0"

  namespace = "myorg"
  name      = "proxy"

  proxy_username = "user"
  proxy_password = "s3cret"
}
```

### Auto-Terminate After 2 Hours

```hcl
module "proxy" {
  source = "github.com/ql4b/terraform-aws-ec2-proxy?ref=v2.0.0"

  namespace = "myorg"
  name      = "proxy"
  ttl_hours = 2
}
```

## Security

- **Network isolation:** Security group restricts inbound to only the specified CIDRs (or auto-detected caller IP)
- **No SSH:** No key pair attached, no port 22 open — access via SSM only
- **Optional auth:** Set `proxy_username` and `proxy_password` to require credentials
- **IMDSv2:** Instance metadata requires session tokens (prevents SSRF attacks)
- **Encrypted storage:** Root EBS volume is encrypted at rest

> **Note:** When using `allowed_cidrs = []` (default), the module calls `checkip.amazonaws.com`
> at plan time to detect your IP. If you're behind a VPN or NAT that changes IPs, set explicit CIDRs.

## Cost

Approximate cost for `t4g.nano` spot in `us-east-1`: **~$0.0016/hour** ($1.15/month if running 24/7). Designed to be deployed and destroyed per-use — typical cost is cents per session.

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Spot instance default | Acceptable for ephemeral workloads; ~70% savings |
| ARM64 (Graviton) | Best price-performance for nano instances |
| Default VPC | Zero pre-existing infra — works in any AWS account |
| No SSH / SSM only | Reduced attack surface; no key management |
| Squid from AL2023 repos | Zero external dependencies |
| Cloud Posse null-label | Consistent naming/tagging |
| Stateless instance | Reprovisioned, never patched in-place |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_http"></a> [http](#provider\_http) | >= 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_this"></a> [this](#module\_this) | cloudposse/label/null | 0.25.0 |

## Resources

| Name | Type |
|------|------|
| [aws_ec2_tag.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_iam_instance_profile.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_security_group.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_spot_instance_request.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/spot_instance_request) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_subnets.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |
| [http_http.caller_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_cidrs"></a> [allowed\_cidrs](#input\_allowed\_cidrs) | List of CIDRs allowed to reach the proxy. When empty (default), the module auto-detects the caller's public IP and restricts access to that single address. | `list(string)` | `[]` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for the proxy. | `string` | `"t4g.nano"` | no |
| <a name="input_proxy_password"></a> [proxy\_password](#input\_proxy\_password) | Password for Squid basic authentication. Both proxy\_username and proxy\_password must be set to enable auth. | `string` | `null` | no |
| <a name="input_proxy_port"></a> [proxy\_port](#input\_proxy\_port) | TCP port Squid listens on. | `number` | `8888` | no |
| <a name="input_proxy_username"></a> [proxy\_username](#input\_proxy\_username) | Username for Squid basic authentication. Both proxy\_username and proxy\_password must be set to enable auth. | `string` | `null` | no |
| <a name="input_spot"></a> [spot](#input\_spot) | Use a spot instance for cost savings. Set to false for on-demand. | `bool` | `true` | no |
| <a name="input_ttl_hours"></a> [ttl\_hours](#input\_ttl\_hours) | Hours after launch before the instance self-terminates. Set to null (default) to disable auto-termination. | `number` | `null` | no |

<details>
<summary>Cloud Posse null-label inputs (click to expand)</summary>

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_tag_map"></a> [additional\_tag\_map](#input\_additional\_tag\_map) | Additional key-value pairs to add to each map in `tags_as_list_of_maps`. | `map(string)` | `{}` | no |
| <a name="input_attributes"></a> [attributes](#input\_attributes) | ID element. Additional attributes to add to `id`. | `list(string)` | `[]` | no |
| <a name="input_context"></a> [context](#input\_context) | Single object for setting entire context at once. | `any` | See `context.tf` | no |
| <a name="input_delimiter"></a> [delimiter](#input\_delimiter) | Delimiter between ID elements. Defaults to `-`. | `string` | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Set to false to prevent the module from creating any resources. | `bool` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | ID element. Usually used for region or role. | `string` | `null` | no |
| <a name="input_id_length_limit"></a> [id\_length\_limit](#input\_id\_length\_limit) | Limit `id` to this many characters (minimum 6). | `number` | `null` | no |
| <a name="input_label_key_case"></a> [label\_key\_case](#input\_label\_key\_case) | Controls the letter case of tag keys. | `string` | `null` | no |
| <a name="input_label_order"></a> [label\_order](#input\_label\_order) | The order in which labels appear in `id`. | `list(string)` | `null` | no |
| <a name="input_label_value_case"></a> [label\_value\_case](#input\_label\_value\_case) | Controls the letter case of ID elements. | `string` | `null` | no |
| <a name="input_labels_as_tags"></a> [labels\_as\_tags](#input\_labels\_as\_tags) | Set of labels to include as tags. | `set(string)` | `["default"]` | no |
| <a name="input_name"></a> [name](#input\_name) | ID element. Usually the component or solution name. | `string` | `null` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | ID element. Usually an abbreviation of your organization name. | `string` | `null` | no |
| <a name="input_regex_replace_chars"></a> [regex\_replace\_chars](#input\_regex\_replace\_chars) | Regex for characters to remove from ID elements. | `string` | `null` | no |
| <a name="input_stage"></a> [stage](#input\_stage) | ID element. Usually used to indicate role. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags. | `map(string)` | `{}` | no |
| <a name="input_tenant"></a> [tenant](#input\_tenant) | ID element. A customer identifier. | `string` | `null` | no |
| <a name="input_descriptor_formats"></a> [descriptor\_formats](#input\_descriptor\_formats) | Describe additional descriptors for the `descriptors` output map. | `any` | `{}` | no |

</details>

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | Public IP address of the proxy instance |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | EC2 instance ID |
| <a name="output_proxy_url"></a> [proxy\_url](#output\_proxy\_url) | Full proxy URL (includes credentials if auth is enabled) |
| <a name="output_instance_type"></a> [instance\_type](#output\_instance\_type) | Instance type of the proxy |
| <a name="output_is_spot"></a> [is\_spot](#output\_is\_spot) | Whether the instance is a spot instance |
| <a name="output_region"></a> [region](#output\_region) | AWS region the proxy is deployed in |
<!-- END_TF_DOCS -->

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.
