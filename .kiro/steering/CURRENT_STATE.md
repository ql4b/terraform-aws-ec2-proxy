# Current State

*Last updated: 2026-08-09*

## Status: MVP — Functional, Not Yet Released

The module is **feature-complete for its minimal use case** but has not been committed or published. All 6 source files exist as untracked files on the `main` branch.

## What Works

- Provisions a Squid HTTP proxy on EC2 with a single `terraform apply`
- Spot and on-demand modes via the `spot` boolean
- Security group properly scopes ingress to `allowed_cidrs`
- IAM role with SSM access enables `aws ssm start-session` for debugging
- Outputs provide `proxy_url` ready for `HTTP_PROXY` env var usage
- Squid configured to hide client identity (`via off`, `forwarded_for delete`)

## What's Missing

| Category | Gap |
|----------|-----|
| **Version control** | No commits yet; no `.gitignore` |
| **Testing** | No Terratest, no `terraform validate` CI step |
| **CI/CD** | No GitHub Actions or equivalent pipeline |
| **Examples** | No `examples/` directory with a ready-to-use tfvars |
| **Documentation** | README is minimal — no architecture diagram, no prereqs section |
| **Locking** | No `.terraform.lock.hcl` checked in |
| **Security hardening** | `allowed_cidrs` defaults to `0.0.0.0/0` (open to world) |
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
| Amazon Linux 2023 | latest (SSM) | AMI resolved at apply-time |
| Squid | AL2023 repo default | Installed via user_data |
