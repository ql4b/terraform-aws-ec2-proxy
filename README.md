# terraform-aws-ec2-proxy

Disposable EC2-based HTTP proxy for IP diversification. Runs a Squid forward proxy on a single-instance Auto Scaling Group, so the proxy can recycle to a fresh public IP without any Terraform state drift.

> **v3 is a breaking redesign.** The proxy is now managed by an Auto Scaling Group instead of a standalone instance. Spot support and the `use_asg` flag were removed, and the `public_ip` / `instance_id` / `proxy_url` / `is_spot` outputs no longer exist (the running instance is dynamic — resolve it live by tag). If you depend on the previous behavior, pin `version = "~> 2.5"`.

## Why an ASG?

The v2 design had a built-in contradiction: `ttl_hours` made the instance terminate itself, but a self-deleting instance is *drift* — Terraform still thought it existed. v3 resolves this by managing an **ASG contract** ("capacity 0..1 from this launch template") instead of a specific instance. The instance churning underneath — TTL shutdown, scale-to-zero, scale-up — is exactly what an ASG absorbs, and `ignore_changes = [desired_capacity]` keeps it out of Terraform state.

IP rotation becomes a cheap `set-desired-capacity` cycle rather than a destroy/recreate `apply`.

## Two modes

The module has two modes, selected purely by whether you set `ttl_hours`:

- **Always-on** (`ttl_hours = null`, default): just the ASG + launch template + security group + IAM instance role. `terraform apply` brings the proxy up; `terraform destroy` tears it down. No Lambda, no EventBridge — minimal footprint.
- **Disposable** (`ttl_hours = N`): additionally creates an EventBridge rule + Lambda. The instance self-terminates after N hours (`shutdown -h`); the `shutting-down` event triggers the Lambda, which sets the ASG's desired capacity to 0 so no replacement launches. Scale back to 1 on demand for a fresh proxy/IP.

## Use Cases

- Rotate source IPs for web scraping or API testing (scale 0→1 for a new IP)
- Validate geo-restrictions or firewall rules from a cloud IP
- Avoid rate limits by cycling proxy instances
- Throwaway proxy with zero residual cost when scaled to zero

## Prerequisites

- Terraform >= 1.0
- AWS account with a **default VPC** (present in all accounts unless manually deleted), or an existing VPC and public subnet
- AWS credentials configured (`aws configure`, env vars, or IAM role)
- No pre-existing infrastructure required

## Quick Start

```hcl
module "proxy" {
  source  = "ql4b/ec2-proxy/aws"
  version = "~> 3.0"

  namespace = "myorg"
  name      = "proxy"
}

output "asg_name" {
  value = module.proxy.asg_name
}
```

```bash
terraform init
terraform apply

# The ASG launches an instance (desired = 1). Resolve its live IP by tag —
# it is NOT a Terraform output, because it changes as the instance recycles:
IP=$(aws ec2 describe-instances \
  --filters "Name=tag:proxy:managed-by,Values=myorg-proxy" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].PublicIpAddress' --output text)

export HTTP_PROXY="http://$IP:8888"
curl http://httpbin.org/ip

# Done — destroy to remove everything
terraform destroy
```

> **Tip:** Always pin to a specific version constraint (e.g. `version = "~> 3.0"`). Browse
> available versions on the [Terraform Registry](https://registry.terraform.io/modules/ql4b/ec2-proxy/aws/latest) page.

### Getting a fresh IP without a re-apply (disposable mode)

With `ttl_hours` set, scale the ASG to hand out a new proxy on demand — no Terraform involved:

```bash
ASG=$(terraform output -raw asg_name)

# fresh proxy (new public IP)
aws autoscaling set-desired-capacity --auto-scaling-group-name "$ASG" --desired-capacity 1

# stop cost (keeps the scaffolding; the TTL Lambda also does this automatically)
aws autoscaling set-desired-capacity --auto-scaling-group-name "$ASG" --desired-capacity 0
```

## Just Want a Proxy? (No Terraform)

This module is built for composition — embedding in a larger Terraform stack.
If you'd rather not write any Terraform, the companion
[**cloudless-proxy**](https://github.com/ql4b/cloudless-proxy) wrapper clones
the module behind a `.env` file and a `proxy` CLI that handles the whole
lifecycle:

```bash
git clone https://github.com/ql4b/cloudless-proxy.git
cd cloudless-proxy
cp .env.example .env    # set your AWS profile + region
source activate
proxy up                # deploy + wait until the proxy is serving
proxy scale-down        # park it at $0; `proxy scale-up` for a fresh IP
proxy down              # tear it all down
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ VPC (default or custom)                             │
│                                                     │
│  Auto Scaling Group (min 0 · max 1 · desired 1)     │
│  └── Launch Template (AL2023 · arm64 · t4g.nano)    │
│        ┌──────────────────────────────────────┐     │
│        │ EC2 instance (on-demand)             │     │
│        │  ┌───────────┐                        │     │
│        │  │   Squid   │ ← port 8888 (HTTP)    │     │
│        │  └───────────┘                        │     │
│        │  IAM Role: AmazonSSMManagedInstance   │     │
│        │  (no SSH key, no inbound port 22)     │     │
│        └──────────────────────────────────────┘     │
│                                                     │
│  Security Group:                                    │
│    ingress: caller IP (auto) → proxy_port/tcp       │
│    egress:  0.0.0.0/0 → all                         │
│                                                     │
│  When ttl_hours is set:                             │
│    EC2 "shutting-down" event → EventBridge → Lambda │
│    → set ASG desired capacity to 0 (no relaunch)    │
└─────────────────────────────────────────────────────┘
```

## Features

| Feature | Details |
|---------|---------|
| **ASG-managed** | Single-instance ASG; recycle to a fresh IP via `set-desired-capacity`, no state drift |
| **ARM64 (Graviton)** | Best price-performance at t4g.nano |
| **Custom VPC support** | Optional `vpc_id` and `subnet_id` — defaults to the region's default VPC |
| **Auto-detected ingress** | When `allowed_cidrs` is empty, restricts to caller's IP/32 |
| **Basic auth** | Optional `proxy_username` + `proxy_password` for Squid authentication |
| **TTL auto-terminate** | `ttl_hours` self-terminates the instance and scales the ASG to zero (no forgotten instances, no drift) |
| **IMDSv2 enforced** | Mitigates SSRF credential theft |
| **Encrypted EBS** | Root volume encryption enabled by default |
| **SSM access** | Debug via `aws ssm start-session` — no SSH keys needed |
| **Privacy headers** | `via off`, `forwarded_for delete` hides client identity |

## Examples

- [`examples/simple`](examples/simple) — All defaults (always-on), caller IP auto-detected
- [`examples/restricted`](examples/restricted) — Explicit CIDRs, custom port
- [`examples/authenticated`](examples/authenticated) — Proxy with HTTP basic auth
- [`examples/ephemeral`](examples/ephemeral) — Disposable mode: TTL + scale-to-zero
- [`examples/custom-vpc`](examples/custom-vpc) — Deploy into a specific VPC and subnet

### With Authentication

```hcl
module "proxy" {
  source  = "ql4b/ec2-proxy/aws"
  version = "~> 3.0"

  namespace = "myorg"
  name      = "proxy"

  proxy_username = "user"
  proxy_password = "s3cret"
}
```

### Disposable — Auto-Terminate After 2 Hours

```hcl
module "proxy" {
  source  = "ql4b/ec2-proxy/aws"
  version = "~> 3.0"

  namespace = "myorg"
  name      = "proxy"
  ttl_hours = 2   # also provisions the scale-to-zero Lambda + EventBridge rule
}
```

### Custom VPC (No Default VPC)

```hcl
module "proxy" {
  source  = "ql4b/ec2-proxy/aws"
  version = "~> 3.0"

  namespace = "myorg"
  name      = "proxy"

  vpc_id    = "vpc-abc123"
  subnet_id = "subnet-def456"   # must be a public subnet
}
```

> **Note:** The subnet must have a route to an internet gateway. The launch
> template sets `associate_public_ip_address = true`, but the subnet still
> needs outbound internet routing for the proxy to function.

## Resolving the proxy IP

The running instance is owned by the ASG and changes whenever it recycles, so its IP and ID are **not** Terraform outputs (a Terraform value would be stale the moment the instance recycles). Resolve the live proxy from EC2 by the `proxy:managed-by` tag, whose value is the module id (`<namespace>-<name>`):

```bash
aws ec2 describe-instances \
  --filters "Name=tag:proxy:managed-by,Values=myorg-proxy" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].PublicIpAddress' --output text
```

Instances also carry a `proxy:ttl-hours` tag when `ttl_hours` is set (its value
is the configured hours; the tag is absent for an always-on proxy), so tooling
can report the TTL live without reading Terraform state.

## Security

- **Network isolation:** Security group restricts inbound to only the specified CIDRs (or auto-detected caller IP)
- **No SSH:** No key pair attached, no port 22 open — access via SSM only
- **Optional auth:** Set `proxy_username` and `proxy_password` to require credentials
- **IMDSv2:** Instance metadata requires session tokens (prevents SSRF attacks)
- **Encrypted storage:** Root EBS volume is encrypted at rest
- **Scoped Lambda (disposable mode):** The scale-to-zero Lambda can only `SetDesiredCapacity` on this module's ASG and read instance tags; it acts only on instances carrying this deployment's `proxy:managed-by` tag

> **Note:** When using `allowed_cidrs = []` (default), the module calls `checkip.amazonaws.com`
> at plan time to detect your IP. If you're behind a VPN or NAT that changes IPs, set explicit CIDRs.

## Cost

Approximate cost for an on-demand `t4g.nano` in `us-east-1`: **~$0.0042/hour** (~$3/month if running 24/7). Scale the ASG to 0 (or use `ttl_hours`) to drop compute cost to zero between uses. The disposable-mode EventBridge rule is free and the Lambda runs briefly on each teardown — effectively $0.

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| ASG (single instance) | Manages a stable contract, not a self-deleting instance — eliminates `ttl_hours` state drift |
| On-demand only | Spot was never interruption-safe; the savings at t4g.nano are negligible and TTL already gives zero idle cost |
| `ignore_changes = [desired_capacity]` | Runtime capacity is driven out-of-band (TTL Lambda, wrapper); Terraform must not fight it |
| Lambda/EventBridge gated on `ttl_hours` | Always-on proxies need no scale-to-zero machinery — keep the footprint minimal |
| ARM64 (Graviton) | Best price-performance for nano instances |
| Default VPC fallback | Zero pre-existing infra — works in any AWS account out of the box |
| `associate_public_ip_address = true` | Required for an internet-facing proxy |
| No SSH / SSM only | Reduced attack surface; no key management |
| Squid from AL2023 repos | Zero external dependencies |
| Cloud Posse null-label | Consistent naming/tagging |
| Stateless instance | Reprovisioned, never patched in-place |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.8.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.58.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.6.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_this"></a> [this](#module\_this) | cloudposse/label/null | 0.25.0 |

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_cloudwatch_event_rule.instance_shutting_down](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.scale_to_zero](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_iam_instance_profile.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.scale_to_zero](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.scale_to_zero](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.scale_to_zero](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.allow_eventbridge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_launch_template.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_security_group.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [archive_file.scale_to_zero](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_subnets.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |
| [http_http.caller_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_tag_map"></a> [additional\_tag\_map](#input\_additional\_tag\_map) | Additional key-value pairs to add to each map in `tags_as_list_of_maps`. Not added to `tags` or `id`.<br/>This is for some rare cases where resources want additional configuration of tags<br/>and therefore take a list of maps with tag key, value, and additional configuration. | `map(string)` | `{}` | no |
| <a name="input_allowed_cidrs"></a> [allowed\_cidrs](#input\_allowed\_cidrs) | List of CIDRs allowed to reach the proxy. When empty (default), the module auto-detects the caller's public IP and restricts access to that single address. | `list(string)` | `[]` | no |
| <a name="input_attributes"></a> [attributes](#input\_attributes) | ID element. Additional attributes (e.g. `workers` or `cluster`) to add to `id`,<br/>in the order they appear in the list. New attributes are appended to the<br/>end of the list. The elements of the list are joined by the `delimiter`<br/>and treated as a single ID element. | `list(string)` | `[]` | no |
| <a name="input_context"></a> [context](#input\_context) | Single object for setting entire context at once.<br/>See description of individual variables for details.<br/>Leave string and numeric variables as `null` to use default value.<br/>Individual variable settings (non-null) override settings in context object,<br/>except for attributes, tags, and additional\_tag\_map, which are merged. | `any` | <pre>{<br/>  "additional_tag_map": {},<br/>  "attributes": [],<br/>  "delimiter": null,<br/>  "descriptor_formats": {},<br/>  "enabled": true,<br/>  "environment": null,<br/>  "id_length_limit": null,<br/>  "label_key_case": null,<br/>  "label_order": [],<br/>  "label_value_case": null,<br/>  "labels_as_tags": [<br/>    "unset"<br/>  ],<br/>  "name": null,<br/>  "namespace": null,<br/>  "regex_replace_chars": null,<br/>  "stage": null,<br/>  "tags": {},<br/>  "tenant": null<br/>}</pre> | no |
| <a name="input_delimiter"></a> [delimiter](#input\_delimiter) | Delimiter to be used between ID elements.<br/>Defaults to `-` (hyphen). Set to `""` to use no delimiter at all. | `string` | `null` | no |
| <a name="input_descriptor_formats"></a> [descriptor\_formats](#input\_descriptor\_formats) | Describe additional descriptors to be output in the `descriptors` output map.<br/>Map of maps. Keys are names of descriptors. Values are maps of the form<br/>`{<br/>   format = string<br/>   labels = list(string)<br/>}`<br/>(Type is `any` so the map values can later be enhanced to provide additional options.)<br/>`format` is a Terraform format string to be passed to the `format()` function.<br/>`labels` is a list of labels, in order, to pass to `format()` function.<br/>Label values will be normalized before being passed to `format()` so they will be<br/>identical to how they appear in `id`.<br/>Default is `{}` (`descriptors` output will be empty). | `any` | `{}` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Set to false to prevent the module from creating any resources | `bool` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | ID element. Usually used for region e.g. 'uw2', 'us-west-2', OR role 'prod', 'staging', 'dev', 'UAT' | `string` | `null` | no |
| <a name="input_id_length_limit"></a> [id\_length\_limit](#input\_id\_length\_limit) | Limit `id` to this many characters (minimum 6).<br/>Set to `0` for unlimited length.<br/>Set to `null` for keep the existing setting, which defaults to `0`.<br/>Does not affect `id_full`. | `number` | `null` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for the proxy. | `string` | `"t4g.nano"` | no |
| <a name="input_label_key_case"></a> [label\_key\_case](#input\_label\_key\_case) | Controls the letter case of the `tags` keys (label names) for tags generated by this module.<br/>Does not affect keys of tags passed in via the `tags` input.<br/>Possible values: `lower`, `title`, `upper`.<br/>Default value: `title`. | `string` | `null` | no |
| <a name="input_label_order"></a> [label\_order](#input\_label\_order) | The order in which the labels (ID elements) appear in the `id`.<br/>Defaults to ["namespace", "environment", "stage", "name", "attributes"].<br/>You can omit any of the 6 labels ("tenant" is the 6th), but at least one must be present. | `list(string)` | `null` | no |
| <a name="input_label_value_case"></a> [label\_value\_case](#input\_label\_value\_case) | Controls the letter case of ID elements (labels) as included in `id`,<br/>set as tag values, and output by this module individually.<br/>Does not affect values of tags passed in via the `tags` input.<br/>Possible values: `lower`, `title`, `upper` and `none` (no transformation).<br/>Set this to `title` and set `delimiter` to `""` to yield Pascal Case IDs.<br/>Default value: `lower`. | `string` | `null` | no |
| <a name="input_labels_as_tags"></a> [labels\_as\_tags](#input\_labels\_as\_tags) | Set of labels (ID elements) to include as tags in the `tags` output.<br/>Default is to include all labels.<br/>Tags with empty values will not be included in the `tags` output.<br/>Set to `[]` to suppress all generated tags.<br/>**Notes:**<br/>  The value of the `name` tag, if included, will be the `id`, not the `name`.<br/>  Unlike other `null-label` inputs, the initial setting of `labels_as_tags` cannot be<br/>  changed in later chained modules. Attempts to change it will be silently ignored. | `set(string)` | <pre>[<br/>  "default"<br/>]</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | ID element. Usually the component or solution name, e.g. 'app' or 'jenkins'.<br/>This is the only ID element not also included as a `tag`.<br/>The "name" tag is set to the full `id` string. There is no tag with the value of the `name` input. | `string` | `null` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | ID element. Usually an abbreviation of your organization name, e.g. 'eg' or 'cp', to help ensure generated IDs are globally unique | `string` | `null` | no |
| <a name="input_proxy_password"></a> [proxy\_password](#input\_proxy\_password) | Password for Squid basic authentication. Both proxy\_username and proxy\_password must be set to enable auth. | `string` | `null` | no |
| <a name="input_proxy_port"></a> [proxy\_port](#input\_proxy\_port) | TCP port Squid listens on. | `number` | `8888` | no |
| <a name="input_proxy_username"></a> [proxy\_username](#input\_proxy\_username) | Username for Squid basic authentication. Both proxy\_username and proxy\_password must be set to enable auth. | `string` | `null` | no |
| <a name="input_regex_replace_chars"></a> [regex\_replace\_chars](#input\_regex\_replace\_chars) | Terraform regular expression (regex) string.<br/>Characters matching the regex will be removed from the ID elements.<br/>If not set, `"/[^a-zA-Z0-9-]/"` is used to remove all characters other than hyphens, letters and digits. | `string` | `null` | no |
| <a name="input_stage"></a> [stage](#input\_stage) | ID element. Usually used to indicate role, e.g. 'prod', 'staging', 'source', 'build', 'test', 'deploy', 'release' | `string` | `null` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | ID of the subnet to launch the instance in. When null (default), the module picks the first subnet in the selected VPC. Must belong to the VPC specified by vpc\_id (or the default VPC when vpc\_id is null). | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags (e.g. `{'BusinessUnit': 'XYZ'}`).<br/>Neither the tag keys nor the tag values will be modified by this module. | `map(string)` | `{}` | no |
| <a name="input_tenant"></a> [tenant](#input\_tenant) | ID element \_(Rarely used, not included by default)\_. A customer identifier, indicating who this instance of a resource is for | `string` | `null` | no |
| <a name="input_ttl_hours"></a> [ttl\_hours](#input\_ttl\_hours) | Hours after launch before the proxy instance self-terminates. When set, the module also creates an EventBridge rule + Lambda that scale the ASG to 0 on shutdown (so no replacement is launched), and Terraform ignores the resulting desired-capacity change. Set to null (default) for an always-on proxy with no auto-termination and no Lambda/EventBridge. | `number` | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC to deploy into. When null (default), the module uses the region's default VPC. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_asg_name"></a> [asg\_name](#output\_asg\_name) | Name of the Auto Scaling Group managing the proxy. Scale it to 1 to hand out a proxy (new public IP) or 0 to stop cost: aws autoscaling set-desired-capacity --auto-scaling-group-name <name> --desired-capacity <0\|1> |
| <a name="output_instance_type"></a> [instance\_type](#output\_instance\_type) | Instance type of the proxy. |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id) | ID of the launch template backing the proxy ASG. |
| <a name="output_region"></a> [region](#output\_region) | AWS region the proxy is deployed in. |
| <a name="output_ttl_hours"></a> [ttl\_hours](#output\_ttl\_hours) | Hours after launch before the instance self-terminates, or null if auto-termination is disabled. |
<!-- END_TF_DOCS -->

## License

Apache 2.0 — see [LICENCE](LICENCE) for details.
