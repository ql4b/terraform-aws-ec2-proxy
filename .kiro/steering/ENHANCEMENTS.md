# Future Enhancements

Prioritized backlog of improvements, grouped by theme.

---

## P0 — Ship It (pre-release hygiene)

- [x] **Initial commit & `.gitignore`** — Ignores `.terraform/`, `*.tfstate*`, `*.tfvars`, `.terraform.lock.hcl`.
- [x] **`terraform fmt` & `terraform validate`** — Clean formatting and valid syntax confirmed.
- [x] **Conventional commits** — All commits follow [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/). See `.kiro/steering/COMMITS.md`.
- [x] **Semantic-release & CI** — GitHub Actions workflow (`.github/workflows/release.yml`) runs `semantic-release` on push to `main`. Automatic tagging replaces manual `git tag`.
- [ ] **Lock file** — Run `terraform init` and decide whether to check in `.terraform.lock.hcl` for reproducible provider versions.

---

## P1 — Security & Hardening

- [ ] **Default `allowed_cidrs` to empty or caller's IP** — Open-to-world default is a foot-gun. Consider requiring explicit opt-in or using a data source to detect caller IP.
- [ ] **Squid basic auth** — Optional username/password passed via variable and injected into `squid.conf`. Prevents unauthorized use even if SG is open.
- [ ] **Squid ACLs for destination domains** — Optional allowlist/denylist to prevent the proxy from being used as an open relay.
- [ ] **IMDSv2 enforcement** — Set `metadata_options { http_tokens = "required" }` on the instance.
- [ ] **Encrypted root volume** — Add `root_block_device { encrypted = true }` for compliance.

---

## P2 — Reliability & Lifecycle

- [ ] **TTL / auto-terminate** — A CloudWatch Events rule or instance tag + Lambda that destroys the instance after N hours, preventing cost leakage from forgotten proxies.
- [ ] **Health check output** — A `null_resource` with a provisioner or an output script that curls through the proxy to confirm it's live.
- [ ] **Spot interruption handling** — Use a Spot Fleet or capacity-optimized allocation to reduce interruption risk, or emit an SNS notification on interruption.
- [ ] **Configurable AZ** — Allow passing a specific subnet ID or AZ preference instead of always taking `ids[0]`.

---

## P3 — Flexibility & Multi-Proxy

- [ ] **`count` or `for_each` support** — Deploy N proxies in parallel for higher throughput or wider IP diversity.
- [ ] **Multiple regions** — Accept a list of regions and deploy one proxy per region (requires provider aliases or a wrapper module).
- [ ] **VPC selection** — Optional `vpc_id` and `subnet_id` inputs; fall back to default VPC only when unset.
- [ ] **SOCKS5 support** — Alternative to HTTP proxy via Dante or SSH tunneling, toggled by variable.
- [ ] **Custom user_data hook** — Allow users to append extra commands (install tools, set env vars) via a `user_data_extra` variable.

---

## P4 — Developer Experience

- [ ] **`examples/` directory** — At minimum: `examples/simple/main.tf` and `examples/restricted/main.tf` (with explicit CIDRs and auth).
- [ ] **Automated tests** — Terratest (Go) or `tftest` (native Terraform testing) that deploys the module, curls through the proxy, and destroys.
- [ ] **CI pipeline** — GitHub Actions with: `fmt -check`, `validate`, `tflint`, `tfsec`/`checkov`, and optional integration test on PR.
- [ ] **terraform-docs** — Auto-generate input/output tables in README via `terraform-docs` hook or CI step.
- [ ] **Pre-commit hooks** — `.pre-commit-config.yaml` with `terraform fmt`, `terraform validate`, `tflint`, `tfsec`.

---

## P5 — Observability

- [ ] **CloudWatch agent / metrics** — Squid access logs shipped to CloudWatch Logs; basic alarm on instance status check failure.
- [ ] **Proxy request counter** — Parse Squid `access.log` into a CloudWatch custom metric for usage visibility.
- [ ] **SSM document for log retrieval** — An `aws_ssm_document` that tails Squid logs without needing shell access.

---

## Non-Goals (Explicitly Out of Scope)

- **High availability / load balancing** — This is a disposable single-node proxy, not a production proxy fleet.
- **Persistent state** — The proxy caches nothing meaningful; reprovisioning is the upgrade path.
- **VPN/tunnel functionality** — If you need a VPN, use a different module (WireGuard, OpenVPN).
- **Windows support** — AL2023 only; no plans for cross-OS.
