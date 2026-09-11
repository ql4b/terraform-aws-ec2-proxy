# Current State

*Last updated: 2026-09-10*

## Status: v3.1.0 — ASG redesign, released

Breaking redesign (v3.0.0): the proxy is now managed by a single-instance **Auto Scaling Group** instead of a standalone instance. This resolves the `ttl_hours` state-drift problem that was inherent to the v2 design (a self-terminating instance is drift). Spot support and the `use_asg` flag are removed; on-demand only. v3.1.0 added the `proxy:ttl-hours` instance tag so tooling can report the TTL live by tag.

**Released & merged** via semantic-release. **Preserved:** v2.x users are unaffected — they stay pinned to `~> 2.5`. The `cloudless-proxy` wrapper consumes this module (`~> 3.0`) and ships the `bin/proxy` lifecycle CLI (scale-up/down, readiness probe, region guard, TTL display).

## What Works

- **ASG-managed proxy** — single-node ASG (`min 0 / max 1 / desired 1`) backed by `aws_launch_template.proxy`. `terraform apply` brings it up, `terraform destroy` tears it down.
- **Two modes, selected by `ttl_hours`:**
  - *Always-on* (`ttl_hours = null`): ASG + launch template + SG + IAM instance role only. No Lambda, no EventBridge.
  - *Disposable* (`ttl_hours = N`): adds an EventBridge rule + Lambda. Instance self-terminates after N hours (`shutdown -h`) → `shutting-down` event → Lambda sets ASG desired to 0 → no relaunch.
- **No state drift** — `ignore_changes = [desired_capacity]` (always). Out-of-band scaling (TTL Lambda, wrapper scale-up/down) never registers as drift. **Verified live:** two full terminate→scale-to-zero cycles + a scale-up produced `terraform plan` = no infrastructure changes.
- **IP diversification via scaling** — scale ASG 0→1 for a fresh instance + new public IP, without a destroy/recreate apply. Verified live (new IP each cycle, proxy served traffic).
- **Caller IP auto-detection** — empty `allowed_cidrs` (default) → queries `checkip.amazonaws.com`, restricts ingress to caller's IP/32.
- **Squid basic auth** — optional `proxy_username` + `proxy_password` via `basic_ncsa_auth`.
- **IMDSv2 enforced**, **encrypted root volume**, **SSM access** (no SSH), privacy headers (`via off`, `forwarded_for delete`) — all on the launch template.
- **Ownership tag** `proxy:managed-by = <module id>` on launched instances; the scale-to-zero Lambda gates on it (won't touch other deployments' instances) and resolves the target ASG from the auto-injected `aws:autoscaling:groupName` tag. When `ttl_hours` is set, instances also carry `proxy:ttl-hours = <N>` so tooling can report the TTL live by tag.
- 22 unit tests pass (`terraform test`); Checkov clean (2 pre-existing findings in the CI skip list) in both modes.

## What Changed from v2 (breaking)

- **Removed resources:** `aws_instance.proxy`, `aws_spot_instance_request.proxy`, `aws_ec2_tag.proxy`.
- **Removed variables:** `spot`, `use_asg`.
- **Removed outputs:** `public_ip`, `instance_id`, `proxy_url`, `is_spot`. The running instance is dynamic — resolve its IP live by the `proxy:managed-by` tag (the wrapper's `bin/proxy url`/`status` do this).
- **New output:** `launch_template_id` (kept `asg_name`, `instance_type`, `region`, `ttl_hours`).

## What's Missing

| Category | Gap |
|----------|-----|
| **Testing** | No integration tests in CI — AWS account setup pending (see `CI_AWS_SETUP.md`). Live validation so far is manual. |
| **Security hardening** | No destination domain ACLs (open relay for CONNECT method) |
| **Observability** | No health check, no CloudWatch alarms, no readiness probe |
| **Multi-proxy** | Single ASG (max 1); no `count`/`for_each` for N proxies |

## Known Limitations

1. **Brief downtime on recycle.** Terminate → scale-up → Squid install is a gap of ~1 min. Acceptable for a disposable proxy.
2. **Single AZ.** Uses `data.aws_subnets.default.ids[0]` (or the provided `subnet_id`) — no AZ selection or failover.
3. **No HTTPS CONNECT validation.** Squid tunnels HTTPS (CONNECT) by default; no ACLs restrict destinations.
4. **Auth credentials in user_data.** When basic auth is enabled, credentials appear in the launch template user_data (base64-encoded, not encrypted). Fine for disposable proxies; not for long-lived shared infra.
5. **Instance IP not in Terraform state.** By design — resolve live by tag. `tf output` will not show the running proxy.
6. **Lambda cold-starts** (~600-700ms) on each scale-to-zero invocation; it still wins the ASG relaunch race by seconds (matching on `shutting-down`, not `terminated`).

## Dependencies

| Dependency | Version | Notes |
|------------|---------|-------|
| Terraform | >= 1.0 | Tested intent: 1.x series |
| AWS Provider | >= 5.0 (locked: 6.58.0) | ASG, launch template, Lambda, EventBridge |
| cloudposse/label/null | 0.25.0 | Naming/tagging framework |
| HTTP Provider | >= 3.0 (locked: 3.6.0) | Caller IP auto-detection |
| Archive Provider | >= 2.0 (locked: 2.8.0) | Packages the scale-to-zero Lambda (disposable mode only) |
| Amazon Linux 2023 | latest (SSM) | AMI resolved at apply-time |
| Squid | AL2023 repo default | Installed via user_data |
| httpd-tools | AL2023 repo default | Installed when auth is enabled (provides `htpasswd`) |

## Repository Layout

```
.
├── .github/workflows/release.yml  # Semantic-release + CI
├── .gitignore
├── .kiro/steering/                 # Project steering docs
│   ├── COMMITS.md
│   ├── CI_AWS_SETUP.md
│   ├── CURRENT_STATE.md
│   ├── ENHANCEMENTS.md
│   └── PROJECT.md
├── .releaserc.yml                  # semantic-release config
├── .terraform.lock.hcl            # Provider lock file (tracked)
├── main.tf                         # Data sources, SG, IAM, launch template, user_data
├── asg.tf                          # ASG + (TTL-gated) scale-to-zero Lambda/EventBridge
├── lambda/scale_to_zero.py         # Scale-to-zero Lambda source
├── variables.tf                    # Module inputs
├── outputs.tf                      # Module outputs
├── versions.tf                     # Provider constraints
├── context.tf                      # Cloud Posse null-label
├── tests/unit.tftest.hcl           # Plan-time unit tests
└── README.md
```
