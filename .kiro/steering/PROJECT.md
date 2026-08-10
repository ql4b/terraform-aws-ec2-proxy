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
│ Default VPC                                        │
│                                                    │
│  ┌─────────────────────────────────────┐           │
│  │ EC2 (spot or on-demand)             │           │
│  │ AL2023 arm64 · t4g.nano             │           │
│  │                                     │           │
│  │  ┌───────────┐                      │           │
│  │  │   Squid   │ ← port 8888 (HTTP)   │           │
│  │  └───────────┘                      │           │
│  │                                     │           │
│  │  IAM Role: AmazonSSMManagedInstance │           │
│  │  (no SSH key, no inbound port 22)   │           │
│  └─────────────────────────────────────┘           │
│                                                    │
│  Security Group:                                   │
│    ingress: var.allowed_cidrs → proxy_port/tcp     │
│    egress:  0.0.0.0/0 → all                        │
└────────────────────────────────────────────────────┘
```

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Spot instance default** | ≈70% cost savings; acceptable for ephemeral workloads |
| **ARM64 (Graviton)** | Best price-performance for t4g.nano |
| **Default VPC** | Zero pre-existing infra required — works in any AWS account |
| **No SSH / SSM only** | Reduced attack surface; no key management overhead |
| **Squid (AL2023 repos)** | Zero external dependencies; available via `dnf` |
| **Cloud Posse null-label** | Consistent naming/tagging across ql4b modules |
| **Minimal user_data** | Instance is stateless; reprovisioned, never patched in-place |

## Module Interface (Summary)

**Inputs:** `instance_type`, `proxy_port`, `allowed_cidrs`, `spot`, `ttl_hours` + all null-label context vars.

**Outputs:** `public_ip`, `instance_id`, `proxy_url`, `instance_type`, `is_spot`, `region`.

## Repository Layout

```
.
├── main.tf          # All resources (data sources, SG, IAM, EC2/Spot, user_data)
├── variables.tf     # 4 module-specific variables
├── outputs.tf       # 6 outputs
├── versions.tf      # Terraform ≥1.0, AWS provider ≥5.0
├── context.tf       # Cloud Posse null-label v0.25.0 integration
└── README.md        # Usage, inputs, outputs, design notes
```
