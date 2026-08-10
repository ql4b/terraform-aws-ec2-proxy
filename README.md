# terraform-aws-ec2-proxy

> Terraform module for a disposable EC2 proxy instance for IP diversification

## Usage

```hcl
module "proxy" {
  source = "github.com/ql4b/terraform-aws-ec2-proxy?ref=v2.0.0"

  namespace = "cloudless"
  name      = "proxy"
}
```

> **Tip:** Always pin to a specific release tag (e.g. `?ref=v2.0.0`) to avoid
> unexpected changes when the module is updated. Browse available versions on the
> [Releases](https://github.com/ql4b/terraform-aws-ec2-proxy/releases) page.

## Examples

- [`examples/simple`](examples/simple) — All defaults, caller IP auto-detected.
- [`examples/restricted`](examples/restricted) — Explicit CIDRs, on-demand instance, custom port.

## Design

- AL2023 arm64 AMI via SSM parameter (always latest)
- Squid HTTP proxy — available in AL2023 default repos
- Default VPC, dedicated security group
- IAM role with `AmazonSSMManagedInstanceCore` — no SSH, no key pairs
- `spot = true` uses `aws_spot_instance_request`, `spot = false` uses `aws_instance`
- IMDSv2 enforced, encrypted root volume

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
