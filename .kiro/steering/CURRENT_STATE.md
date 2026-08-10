# Current State

*Last updated: 2026-08-10*

## Status: v2.0.0 — Preparing for Public Release

The module is **feature-complete** and being prepared for public repository visibility. Squid basic auth, lock file, and README polish are shipping in this release.

## What Works

- Provisions a Squid HTTP proxy on EC2 with a single `terraform apply`
- Spot and on-demand modes via the `spot` boolean
- Security group properly scopes ingress to `allowed_cidrs`
- **Caller IP auto-detection** — When `allowed_cidrs` is empty (default), the module queries `checkip.amazonaws.com` and restricts ingress to the caller's IP/32
- IAM role with SSM access enables `aws ssm start-session` for debugging
- Outputs provide `proxy_url` ready for `HTTP_PROXY` env var usage
- Squid configured to hide client identity (`via off`, `forwarded_for delete`)
- Conventional commits enforced; semantic-release handles tagging/releases
- GitHub Actions CI pipeline runs on push to `main` and on pull requests
- Static validation in CI: `terraform fmt -check`, `terraform validate`, `tflint`
- IMDSv2 enforced (`http_tokens = "required"`) — mitigates SSRF credential theft
- Encrypted root volume (`encrypted = true`) — meets compliance baselines for EBS encryption
- **TTL / auto-terminate** — Optional `ttl_hours` variable; instance self-terminates after N hours via `shutdown -h` + `instance_initiated_shutdown_behavior = "terminate"`
- **Squid basic auth** — Optional `proxy_username` + `proxy_password` variables enable HTTP basic authentication via `basic_ncsa_auth`
- **Lock file checked in** — `.terraform.lock.hcl` tracked with hashes for `darwin_arm64` and `linux_amd64`
- **README polished** — Quick-start, architecture diagram, prerequisites, security section, cost estimate, and full input/output documentation

## What's Missing

| Category | Gap |
|----------|-----|
| **Testing** | No integration tests — CI AWS account setup pending (see `CI_AWS_SETUP.md`) |
| **Security hardening** | No destination domain ACLs (open relay for CONNECT method) |
| **Observability** | No health check, no CloudWatch alarms, no readiness probe |
| **Multi-proxy** | Only supports a single instance; no `count` or `for_each` at the module level |

## Known Limitations

1. **Spot interruption = downtime.** No replacement strategy; user must re-apply.
2. **Single AZ.** Uses `data.aws_subnets.default.ids[0]` — no AZ selection or failover.
3. **No HTTPS CONNECT validation.** Squid will tunnel HTTPS (CONNECT method) by default, but no ACLs restrict destination domains.
4. **Tagging on spot instances** uses the `aws_ec2_tag` resource workaround — acceptable but adds plan complexity.
5. **Auth credentials in user_data.** When basic auth is enabled, credentials appear in the instance user_data (base64-encoded but not encrypted). Acceptable for disposable proxies; not suitable for long-lived shared infrastructure.

## Dependencies

| Dependency | Version | Notes |
|------------|---------|-------|
| Terraform | >= 1.0 | Tested intent: 1.x series |
| AWS Provider | >= 5.0 (locked: 6.58.0) | Uses modern resource attributes |
| cloudposse/label/null | 0.25.0 | Naming/tagging framework |
| HTTP Provider | >= 3.0 (locked: 3.6.0) | Used for caller IP auto-detection |
| Amazon Linux 2023 | latest (SSM) | AMI resolved at apply-time |
| Squid | AL2023 repo default | Installed via user_data |
| httpd-tools | AL2023 repo default | Installed when auth is enabled (provides `htpasswd`) |

## Repository Layout

```
.
├── .github/workflows/release.yml  # Semantic-release CI
├── .gitignore
├── .kiro/steering/                 # Project steering docs
│   ├── COMMITS.md
│   ├── CI_AWS_SETUP.md
│   ├── CURRENT_STATE.md
│   ├── ENHANCEMENTS.md
│   └── PROJECT.md
├── .releaserc.yml                  # semantic-release config
├── .terraform.lock.hcl            # Provider lock file (tracked)
├── main.tf                         # All resources
├── variables.tf                    # Module inputs
├── outputs.tf                      # Module outputs
├── versions.tf                     # Provider constraints
├── context.tf                      # Cloud Posse null-label
└── README.md
```
