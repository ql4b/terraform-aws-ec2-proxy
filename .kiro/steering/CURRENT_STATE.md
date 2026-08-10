# Current State

*Last updated: 2026-08-10*

## Status: v1.0.0 — Released

The module is **feature-complete for its minimal use case** and published on GitHub. First push to `main` triggers semantic-release to create `v1.0.0`.

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

## What's Missing

| Category | Gap |
|----------|-----|
| **Testing** | No Terratest, no integration tests |
| **Documentation** | README is minimal — no architecture diagram, no prereqs section |
| **Locking** | No `.terraform.lock.hcl` checked in |
| **Security hardening** | No Squid auth; no destination ACLs |
| **Observability** | No health check, no CloudWatch alarms, no readiness probe |
| **Lifecycle** | No auto-termination / TTL mechanism |
| **Multi-proxy** | Only supports a single instance; no `count` or `for_each` at the module level |

## Known Limitations

1. **Spot interruption = downtime.** No replacement strategy; user must re-apply.
2. **Single AZ.** Uses `data.aws_subnets.default.ids[0]` — no AZ selection or failover.
3. **No authentication.** Squid is configured with `http_access allow all`. Anyone who can reach the port can use the proxy.
4. **No HTTPS CONNECT validation.** Squid will tunnel HTTPS (CONNECT method) by default, but no ACLs restrict destination domains.
5. **Tagging on spot instances** uses the `aws_ec2_tag` resource workaround — acceptable but adds plan complexity.

## Dependencies

| Dependency | Version | Notes |
|------------|---------|-------|
| Terraform | ≥ 1.0 | Tested intent: 1.x series |
| AWS Provider | ≥ 5.0 | Uses modern resource attributes |
| cloudposse/label/null | 0.25.0 | Naming/tagging framework |
| HTTP Provider | ≥ 3.0 | Used for caller IP auto-detection |
| Amazon Linux 2023 | latest (SSM) | AMI resolved at apply-time |
| Squid | AL2023 repo default | Installed via user_data |

## Repository Layout

```
.
├── .github/workflows/release.yml  # Semantic-release CI
├── .gitignore
├── .kiro/steering/                 # Project steering docs
│   ├── COMMITS.md
│   ├── CURRENT_STATE.md
│   ├── ENHANCEMENTS.md
│   └── PROJECT.md
├── .releaserc.yml                  # semantic-release config
├── main.tf                         # All resources
├── variables.tf                    # Module inputs
├── outputs.tf                      # Module outputs
├── versions.tf                     # Provider constraints
├── context.tf                      # Cloud Posse null-label
└── README.md
```
