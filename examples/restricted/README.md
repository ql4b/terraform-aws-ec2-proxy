# Restricted example

Runs [terraform-aws-ec2-proxy](../../) with explicit `allowed_cidrs` and a
custom `proxy_port` instead of the default auto-detected caller IP. Use this
when the proxy needs to be reachable from known networks (an office range, a
VPN) rather than a single address.

```bash
terraform apply
```

Demonstrates: explicit ingress CIDRs, a non-default port (3128), and a larger
instance type. See the [module README](../../) for all inputs and the other
examples.
