# Custom VPC example

Runs [terraform-aws-ec2-proxy](../../) in a specific VPC and public subnet
instead of the region's default VPC. Use this when the account has no default
VPC (some regions / locked-down accounts) or you want the proxy in an existing
network.

```bash
terraform apply -var 'vpc_id=vpc-abc123' -var 'subnet_id=subnet-def456'
```

The subnet must be public (a route to an internet gateway). The module sets
`associate_public_ip_address = true` so the instance always gets a public IP.

See the [module README](../../) for all inputs and the other examples.
