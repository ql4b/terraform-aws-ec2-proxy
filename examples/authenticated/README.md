# Authenticated example

Runs [terraform-aws-ec2-proxy](../../) with Squid HTTP basic authentication.
Set `proxy_username` and `proxy_password` and the proxy requires credentials —
useful when the proxy is reachable by more than just your IP.

```bash
terraform apply -var 'proxy_username=user' -var 'proxy_password=s3cret'
```

Credentials are baked into the launch template user_data. Resolve the running
instance's IP live by tag (the instance is ASG-managed, so it isn't a Terraform
output), then use `http://<user>:<pass>@<ip>:8888`.

See the [module README](../../) for all inputs and the other examples.
