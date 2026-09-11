# Simple example

The minimal way to run [terraform-aws-ec2-proxy](../../): a disposable Squid
forward proxy with all defaults. Ingress is auto-restricted to your current
public IP (detected at plan time).

```bash
terraform init && terraform apply
```

The proxy runs in a single-node Auto Scaling Group, so the instance is dynamic
and its IP is not a Terraform output. Resolve it live by tag:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:proxy:managed-by,Values=myorg-proxy" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].PublicIpAddress' --output text
```

`terraform destroy` when done — no residual cost.

See the [module README](../../) for all inputs and the other examples
(`authenticated`, `restricted`, `ephemeral`, `custom-vpc`).
