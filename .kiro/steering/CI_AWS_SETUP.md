# CI AWS Account Setup

Plan for enabling integration tests in GitHub Actions with a dedicated, isolated AWS account.

---

## Goal

Run `terraform apply` → validate proxy → `terraform destroy` in CI without risking the main AWS account or leaking costs.

---

## Architecture

```
Management Account
└── OU: CI/Testing
    └── Account: terraform-ci-testing (dedicated, cost-isolated)
```

GitHub Actions authenticates via OIDC federation — no long-lived credentials stored in secrets.

---

## Setup Steps

### 1. Create dedicated AWS account

- [ ] Create a new OU `CI/Testing` under the organization root
- [ ] Create account `terraform-ci-testing` inside that OU
- [ ] Note the account ID for subsequent steps

### 2. Apply SCP to the OU (blast-radius control)

- [ ] Restrict allowed services to: EC2, VPC, IAM, SSM, STS, S3 (for state if needed)
- [ ] Restrict allowed regions to a single region (e.g., `eu-west-1`)
- [ ] Deny expensive actions: `ec2:RunInstances` for instance types larger than `t4g.small`

### 3. Set up OIDC identity provider in CI account

- [ ] Create the GitHub OIDC provider in IAM:
  - Provider URL: `https://token.actions.githubusercontent.com`
  - Audience: `sts.amazonaws.com`
- [ ] Create IAM role `github-ci-terraform` with trust policy:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:ql4b/terraform-aws-ec2-proxy:*"
        }
      }
    }]
  }
  ```
- [ ] Attach permissions policy to the role (least-privilege for module resources):
  - `ec2:*` scoped to the test region
  - `iam:CreateRole`, `iam:DeleteRole`, `iam:AttachRolePolicy`, `iam:DetachRolePolicy`, `iam:CreateInstanceProfile`, `iam:DeleteInstanceProfile`, `iam:AddRoleToInstanceProfile`, `iam:RemoveRoleFromInstanceProfile`, `iam:PassRole`, `iam:GetRole`, `iam:GetInstanceProfile`, `iam:ListInstanceProfilesForRole`, `iam:TagRole`
  - `ssm:GetParameter` (for AMI lookup)
  - `sts:GetCallerIdentity`

### 4. Set budget alarm

- [ ] Create a $10/month budget on the CI account with email notification
- [ ] Optionally add an auto-action to stop EC2 instances if budget exceeds threshold

### 5. Configure GitHub Actions workflow

- [ ] Add integration test job to `release.yml` (or separate `integration.yml`):
  ```yaml
  integration-test:
    name: Integration Test
    needs: validate
    if: github.event_name == 'workflow_dispatch' || (github.event_name == 'push' && github.ref == 'refs/heads/main')
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~> 1.0"

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-ci-terraform
          aws-region: eu-west-1

      - name: Deploy and test
        run: |
          cd examples/simple
          terraform init
          terraform apply -auto-approve
          PROXY_URL=$(terraform output -raw proxy_url)
          sleep 60  # wait for user_data to complete
          PROXY_IP=$(curl -sf -x "$PROXY_URL" http://httpbin.org/ip | jq -r .origin)
          EXPECTED_IP=$(terraform output -raw public_ip)
          [ "$PROXY_IP" = "$EXPECTED_IP" ] && echo "PASS" || (echo "FAIL: got $PROXY_IP, expected $EXPECTED_IP"; exit 1)

      - name: Destroy
        if: always()
        run: |
          cd examples/simple
          terraform destroy -auto-approve
  ```
- [ ] Add `workflow_dispatch` trigger to allow manual runs

### 6. Verify end-to-end

- [ ] Trigger a manual workflow run
- [ ] Confirm: OIDC auth works, apply succeeds, proxy responds, destroy cleans up
- [ ] Check cost in CI account billing dashboard

---

## Decisions to Make

| Question | Options | Notes |
|----------|---------|-------|
| Trigger frequency | On push to main / nightly / manual only | Manual + push to main recommended initially |
| Terraform state | Local (ephemeral) vs S3 backend | Local is fine for CI; no shared state needed |
| Test region | `eu-west-1` / `us-east-1` | Pick cheapest or closest; SCP enforces it |
| Timeout for user_data | Fixed sleep vs poll SSM / health check | Fixed sleep (60s) is simplest to start |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Forgotten resources (failed destroy) | Budget alarm + nightly cleanup Lambda in CI account |
| OIDC misconfiguration exposes role | Trust policy scoped to `repo:ql4b/terraform-aws-ec2-proxy:*` only |
| Tests flake on spot interruption | Use `spot = false` in integration tests |
| Cost creep from frequent runs | Manual trigger initially; budget cap at $10/month |
