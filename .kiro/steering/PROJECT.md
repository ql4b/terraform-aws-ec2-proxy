# Project Overview

## What This Module Does

`terraform-aws-ec2-proxy` provisions a disposable, single-instance HTTP proxy on AWS EC2 for **IP diversification**. It deploys a Squid forward proxy on an Amazon Linux 2023 ARM64 instance that gives callers a fresh public IP on every `terraform apply` cycle.

## Why It Exists

When you need to make outbound HTTP requests from varying IP addresses — scraping, testing geo-restrictions, avoiding rate limits, or validating firewall rules — spinning up a cloud proxy is the simplest and cheapest path. This module codifies that pattern into a one-command operation:

1. Deploy → get a proxy URL with a new public IP.
2. Use the proxy for your workload.
3. Destroy → no residual cost.

The design intentionally optimizes for **low cost and disposability** over durability or high availability.

## Architecture

```
┌────────────────────────────────────────────────────┐
│ VPC (default or custom)                            │
│                                                    │
│  Auto Scaling Group (min 0 · max 1 · desired 1)    │
│  └── Launch Template (AL2023 arm64 · t4g.nano)     │
│        ┌─────────────────────────────────────┐     │
│        │ EC2 instance (on-demand)            │     │
│        │  ┌───────────┐                      │     │
│        │  │   Squid   │ ← port 8888 (HTTP)   │     │
│        │  └───────────┘                      │     │
│        │  IAM Role: AmazonSSMManagedInstance │     │
│        │  (no SSH key, no inbound port 22)   │     │
│        └─────────────────────────────────────┘     │
│                                                    │
│  Security Group:                                   │
│    ingress: allowed_cidrs (or caller IP) → port    │
│    egress:  0.0.0.0/0 → all                        │
│                                                    │
│  When ttl_hours set:                               │
│    "shutting-down" event → EventBridge → Lambda    │
│    → ASG desired = 0 (no relaunch, no drift)       │
└────────────────────────────────────────────────────┘
```

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **ASG (single instance)** | Manages a stable capacity contract, not a self-deleting instance — eliminates `ttl_hours` state drift |
| **On-demand only** | Spot was never interruption-safe; negligible savings at t4g.nano, and TTL already gives zero idle cost |
| **`ignore_changes = [desired_capacity]`** | Runtime capacity is driven out-of-band (TTL Lambda, wrapper) — Terraform must not fight it |
| **Lambda/EventBridge gated on `ttl_hours`** | Always-on proxies need no scale-to-zero machinery — minimal footprint |
| **ARM64 (Graviton)** | Best price-performance for t4g.nano |
| **Default VPC** | Zero pre-existing infra required — works in any AWS account |
| **No SSH / SSM only** | Reduced attack surface; no key management overhead |
| **Squid (AL2023 repos)** | Zero external dependencies; available via `dnf` |
| **Cloud Posse null-label** | Consistent naming/tagging across ql4b modules |
| **Minimal user_data** | Instance is stateless; reprovisioned, never patched in-place |

## Module Interface (Summary)

**Inputs:** `instance_type`, `proxy_port`, `allowed_cidrs`, `ttl_hours`, `proxy_username`, `proxy_password`, `vpc_id`, `subnet_id` + all null-label context vars.

**Outputs:** `asg_name`, `launch_template_id`, `instance_type`, `region`, `ttl_hours`. (The running instance's IP/ID are intentionally not outputs — it is dynamic; resolve it live by the `proxy:managed-by` tag.)

## Repository Layout

```
.
├── main.tf          # Data sources, SG, IAM, launch template, user_data
├── asg.tf           # ASG + (ttl_hours-gated) scale-to-zero Lambda/EventBridge
├── lambda/scale_to_zero.py  # Scale-to-zero Lambda source
├── variables.tf     # Module-specific variables
├── outputs.tf       # Module outputs
├── versions.tf      # Terraform ≥1.0, AWS provider ≥5.0, http, archive
├── context.tf       # Cloud Posse null-label v0.25.0 integration
├── tests/unit.tftest.hcl  # Plan-time unit tests
└── README.md        # Usage, inputs, outputs, design notes
```
