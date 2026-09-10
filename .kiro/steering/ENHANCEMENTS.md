# Future Enhancements

Prioritized backlog of improvements, grouped by theme.

---

## P0 — Ship It (pre-release hygiene)

- [x] **Initial commit & `.gitignore`** — Ignores `.terraform/`, `*.tfstate*`, `*.tfvars`, `.terraform.lock.hcl`.
- [x] **`terraform fmt` & `terraform validate`** — Clean formatting and valid syntax confirmed.
- [x] **Conventional commits** — All commits follow [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/). See `.kiro/steering/COMMITS.md`.
- [x] **Semantic-release & CI** — GitHub Actions workflow (`.github/workflows/release.yml`) runs `semantic-release` on push to `main`. Automatic tagging replaces manual `git tag`.
- [x] **Lock file** — `.terraform.lock.hcl` checked in with hashes for `darwin_arm64` and `linux_amd64`.

---

## P1 — Security & Hardening

- [x] **Default `allowed_cidrs` to empty or caller's IP** — When `allowed_cidrs` is empty (default), the module auto-detects the caller's public IP via `checkip.amazonaws.com` and restricts ingress to that single /32.
- [x] **Squid basic auth** — Optional `proxy_username`/`proxy_password` variables; when both set, Squid requires HTTP basic authentication via `basic_ncsa_auth`.
- [ ] **Squid ACLs for destination domains** — Optional allowlist/denylist to prevent the proxy from being used as an open relay.
- [x] **IMDSv2 enforcement** — Set `metadata_options { http_tokens = "required" }` on the instance.
- [x] **Encrypted root volume** — Add `root_block_device { encrypted = true }` for compliance.

---

## P2 — Reliability & Lifecycle

- [x] **TTL / auto-terminate** — `ttl_hours` variable triggers `shutdown -h` in user_data + `instance_initiated_shutdown_behavior = "terminate"`. In v3, TTL also drives the ASG to zero (via the scale-to-zero Lambda) so no replacement launches — drift-free.
- [ ] **Health check output** — A `null_resource` with a provisioner or an output script that curls through the proxy to confirm it's live.
- [x] **Spot interruption handling** — *Resolved by removal.* Spot was never interruption-safe and was dropped in v3 (on-demand only); the negligible savings at t4g.nano didn't justify completing it. The ASG would make spot viable later (reclaim rides the same `shutting-down` → scale-to-zero path) if reintroduced.
- [ ] **Configurable AZ** — Allow passing a specific subnet ID or AZ preference instead of always taking `ids[0]`.

---

## P3 — Flexibility & Multi-Proxy

- [x] **Launch template extraction** — Shared `aws_launch_template.proxy` captures the instance config from module inputs; the ASG consumes it. (Shipped in the v3 ASG redesign.)
- [x] **ASG-managed proxy** *(v3.0.0, breaking)* — The proxy is a single-node Auto Scaling Group. Solves the `ttl_hours` state-drift problem: the instance self-terminates (`shutdown -h`), an EventBridge rule on the `shutting-down` event triggers a Lambda that sets the ASG `desired_capacity` to 0, and Terraform `ignore_changes` on `desired_capacity` keeps the out-of-band scaling out of state. Validated live (terminate→scale-to-zero + scale-up, zero drift). Lambda/EventBridge are gated on `ttl_hours != null` (always-on mode needs neither). Spot and `use_asg` removed.
- [ ] **`count` or `for_each` support** — Deploy N proxies in parallel for higher throughput or wider IP diversity.
- [ ] **Multiple regions** — Accept a list of regions and deploy one proxy per region (requires provider aliases or a wrapper module).
- [ ] **VPC selection** — Optional `vpc_id` and `subnet_id` inputs; fall back to default VPC only when unset.
- [ ] **SOCKS5 support** — Alternative to HTTP proxy via Dante or SSH tunneling, toggled by variable.
- [ ] **Custom user_data hook** — Allow users to append extra commands (install tools, set env vars) via a `user_data_extra` variable.

---

## P4 — Developer Experience

- [x] **`examples/` directory** — `examples/simple/main.tf` and `examples/restricted/main.tf` (with explicit CIDRs).
- [ ] **Automated tests** — Integration test that deploys the module, curls through the proxy, and destroys. Requires CI AWS account setup — see `.kiro/steering/CI_AWS_SETUP.md`.
- [x] **CI pipeline** — GitHub Actions with: `fmt -check`, `validate`, `tflint`, `checkov` on PRs and push to `main`.
- [x] **terraform-docs** — Auto-generate input/output tables in README via `terraform-docs/gh-actions` on push to `main`.
- [ ] **Pre-commit hooks** — `.pre-commit-config.yaml` with `terraform fmt`, `terraform validate`, `tflint`, `tfsec`.

---

## P5 — Observability

- [ ] **CloudWatch agent / metrics** — Squid access logs shipped to CloudWatch Logs; basic alarm on instance status check failure.
- [ ] **Proxy request counter** — Parse Squid `access.log` into a CloudWatch custom metric for usage visibility.
- [ ] **SSM document for log retrieval** — An `aws_ssm_document` that tails Squid logs without needing shell access.

---

## P6 — Public Repo Safeguards

- [ ] **Pre-commit secret scanning** — Add `gitleaks` or `trufflehog` to catch credentials, keys, and tokens before they reach the remote.
- [ ] **GitHub secret scanning** — Enable GitHub's built-in secret scanning (free for public repos) with push protection.
- [ ] **Steering file content linter** — CI step or pre-commit hook that rejects patterns in `.kiro/steering/` matching AWS account IDs (`\d{12}`), access keys (`AKIA*`), ARNs, or real IP/CIDR ranges.
- [ ] **Sensitive pattern guardrails** — Define a `.secret-patterns` file with regexes; CI fails if any tracked file matches. Prevents accidental disclosure of infra details as the project evolves.

---

## Non-Goals (Explicitly Out of Scope)

- **High availability / load balancing** — This is a disposable single-node proxy, not a production proxy fleet.
- **Persistent state** — The proxy caches nothing meaningful; reprovisioning is the upgrade path.
- **VPN/tunnel functionality** — If you need a VPN, use a different module (WireGuard, OpenVPN).
- **Windows support** — AL2023 only; no plans for cross-OS.
