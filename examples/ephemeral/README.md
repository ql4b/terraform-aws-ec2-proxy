# Ephemeral (disposable) example

Runs [terraform-aws-ec2-proxy](../../) with `ttl_hours` set — the proxy
self-terminates after the TTL and the Auto Scaling Group scales itself to zero,
with no Terraform state drift. This is the "disposable proxy that cleans up
after itself" mode.

```bash
terraform apply   # ttl_hours = 2
```

When `ttl_hours` is set the module also creates the scale-to-zero Lambda +
EventBridge rule. To hand out a fresh proxy (new IP) on demand without a
re-apply:

```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name "$(terraform output -raw asg_name)" \
  --desired-capacity 1
```

See the [module README](../../) for all inputs and the other examples.
