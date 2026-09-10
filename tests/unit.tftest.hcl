# Unit tests for terraform-aws-ec2-proxy (v3: ASG-only, on-demand)
# These run with `command = plan` — no real resources are created.

mock_provider "aws" {
  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-mock12345"
    }
  }
  mock_data "aws_vpc" {
    defaults = {
      id = "vpc-mock12345"
    }
  }
  mock_data "aws_subnets" {
    defaults = {
      ids = ["subnet-mock1", "subnet-mock2"]
    }
  }
  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }
}

mock_provider "http" {
  mock_data "http" {
    defaults = {
      response_body = "203.0.113.1\n"
      status_code   = 200
    }
  }
}

mock_provider "archive" {}

# --- Core ASG (always present) ---

run "creates_asg" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
  }

  assert {
    condition     = aws_autoscaling_group.proxy.min_size == 0
    error_message = "ASG min_size should be 0 (allows scale-to-zero)"
  }

  assert {
    condition     = aws_autoscaling_group.proxy.max_size == 1
    error_message = "ASG max_size should be 1 (single-node proxy)"
  }

  assert {
    condition     = aws_autoscaling_group.proxy.desired_capacity == 1
    error_message = "ASG desired_capacity should start at 1"
  }

  assert {
    condition     = length(aws_autoscaling_group.proxy.launch_template) == 1
    error_message = "ASG should be wired to the launch template"
  }
}

run "asg_honors_subnet_id" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
    vpc_id    = "vpc-custom123"
    subnet_id = "subnet-custom456"
  }

  assert {
    condition     = contains(aws_autoscaling_group.proxy.vpc_zone_identifier, "subnet-custom456")
    error_message = "ASG should launch into the provided subnet_id"
  }

  assert {
    condition     = aws_launch_template.proxy.network_interfaces[0].subnet_id == "subnet-custom456"
    error_message = "Launch template network interface should use the provided subnet_id"
  }
}

# --- Launch template hardening ---

run "imdsv2_enforced" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
  }

  assert {
    condition     = aws_launch_template.proxy.metadata_options[0].http_tokens == "required"
    error_message = "Launch template must enforce IMDSv2 (http_tokens=required)"
  }
}

run "root_volume_encrypted" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
  }

  assert {
    condition     = tobool(aws_launch_template.proxy.block_device_mappings[0].ebs[0].encrypted) == true
    error_message = "Launch template root volume must be encrypted"
  }
}

run "public_ip_and_sg_on_network_interface" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
  }

  assert {
    condition     = tobool(aws_launch_template.proxy.network_interfaces[0].associate_public_ip_address) == true
    error_message = "Launch template must assign a public IP (internet-facing proxy)"
  }
}

# --- TTL / shutdown behavior ---

run "ttl_sets_terminate_behavior" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
    ttl_hours = 4
  }

  assert {
    condition     = aws_launch_template.proxy.instance_initiated_shutdown_behavior == "terminate"
    error_message = "With ttl_hours set, shutdown behavior should be 'terminate'"
  }

  assert {
    condition     = output.ttl_hours == 4
    error_message = "ttl_hours output should reflect the variable value"
  }
}

run "no_ttl_sets_stop_behavior" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
  }

  assert {
    condition     = aws_launch_template.proxy.instance_initiated_shutdown_behavior == "stop"
    error_message = "Without ttl_hours, shutdown behavior should be 'stop'"
  }
}

# --- Scale-to-zero automation: gated on ttl_hours ---

run "no_lambda_without_ttl" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
  }

  assert {
    condition     = length(aws_lambda_function.scale_to_zero) == 0
    error_message = "Scale-to-zero Lambda must NOT exist when ttl_hours is null (always-on mode)"
  }

  assert {
    condition     = length(aws_cloudwatch_event_rule.instance_shutting_down) == 0
    error_message = "EventBridge rule must NOT exist when ttl_hours is null"
  }

  assert {
    condition     = length(aws_iam_role.scale_to_zero) == 0
    error_message = "Scale-to-zero IAM role must NOT exist when ttl_hours is null"
  }
}

run "lambda_created_with_ttl" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
    ttl_hours = 1
  }

  assert {
    condition     = length(aws_lambda_function.scale_to_zero) == 1
    error_message = "Scale-to-zero Lambda must exist when ttl_hours is set"
  }

  assert {
    condition     = aws_lambda_function.scale_to_zero[0].handler == "scale_to_zero.handler"
    error_message = "Lambda handler should be scale_to_zero.handler"
  }

  assert {
    condition     = aws_lambda_function.scale_to_zero[0].environment[0].variables["MANAGED_BY"] == "test-proxy"
    error_message = "Lambda MANAGED_BY env var should equal the module id (the ownership tag value)"
  }
}

run "scale_to_zero_rule_matches_shutting_down" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
    ttl_hours = 1
  }

  assert {
    condition     = strcontains(aws_cloudwatch_event_rule.instance_shutting_down[0].event_pattern, "shutting-down")
    error_message = "EventBridge rule must match the EC2 'shutting-down' state event"
  }

  assert {
    condition     = strcontains(aws_cloudwatch_event_rule.instance_shutting_down[0].event_pattern, "aws.ec2")
    error_message = "EventBridge rule must match the aws.ec2 source"
  }
}

run "lambda_permission_targets_eventbridge" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
    ttl_hours = 1
  }

  assert {
    condition     = aws_lambda_permission.allow_eventbridge[0].principal == "events.amazonaws.com"
    error_message = "Lambda permission should allow invocation from EventBridge"
  }
}

# --- Ownership tag (used by the scale-to-zero Lambda) ---

run "instances_carry_ownership_tag" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
  }

  assert {
    condition     = aws_launch_template.proxy.tag_specifications[0].tags["proxy:managed-by"] == "test-proxy"
    error_message = "Launched instances must carry the proxy:managed-by ownership tag"
  }
}

# --- Security group ---

run "custom_port_in_security_group" {
  command = plan

  variables {
    namespace  = "test"
    name       = "proxy"
    proxy_port = 3128
  }

  assert {
    condition     = one([for r in aws_security_group.proxy.ingress : r.from_port if r.from_port == 3128]) == 3128
    error_message = "Security group ingress should use the custom proxy port"
  }
}

run "explicit_cidrs_used" {
  command = plan

  variables {
    namespace     = "test"
    name          = "proxy"
    allowed_cidrs = ["10.0.0.0/8", "192.168.1.0/24"]
  }

  assert {
    condition     = length(data.http.caller_ip) == 0
    error_message = "Should not call checkip.amazonaws.com when allowed_cidrs is explicit"
  }

  assert {
    condition     = one([for r in aws_security_group.proxy.ingress : true if contains(r.cidr_blocks, "10.0.0.0/8")]) == true
    error_message = "Security group should include the first explicit CIDR"
  }
}

run "empty_cidrs_triggers_auto_detect" {
  command = plan

  variables {
    namespace     = "test"
    name          = "proxy"
    allowed_cidrs = []
  }

  assert {
    condition     = length(data.http.caller_ip) == 1
    error_message = "Empty allowed_cidrs should trigger caller IP auto-detection"
  }
}

run "egress_allows_all" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
  }

  assert {
    condition     = one([for r in aws_security_group.proxy.egress : true if contains(r.cidr_blocks, "0.0.0.0/0")]) == true
    error_message = "Egress should allow all outbound traffic (0.0.0.0/0)"
  }
}

# --- IAM (instance role) ---

run "iam_role_has_ssm_policy" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.ssm.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "IAM role should have SSM managed instance policy attached"
  }
}

run "iam_role_trust_policy_allows_ec2" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
  }

  assert {
    condition     = strcontains(aws_iam_role.proxy.assume_role_policy, "ec2.amazonaws.com")
    error_message = "IAM role trust policy should allow ec2.amazonaws.com"
  }
}

# --- Auth ---

run "auth_enabled_with_both_credentials" {
  command = plan

  variables {
    namespace      = "test"
    name           = "proxy"
    proxy_username = "testuser"
    proxy_password = "testpass"
  }

  assert {
    condition     = strcontains(base64decode(aws_launch_template.proxy.user_data), "basic_ncsa_auth")
    error_message = "With credentials set, user_data should configure Squid basic auth"
  }
}

# --- Custom VPC / subnet lookups ---

run "custom_vpc_skips_default_vpc_lookup" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
    vpc_id    = "vpc-custom123"
  }

  assert {
    condition     = length(data.aws_vpc.default) == 0
    error_message = "Should not look up the default VPC when vpc_id is provided"
  }

  assert {
    condition     = aws_security_group.proxy.vpc_id == "vpc-custom123"
    error_message = "Security group should use the provided vpc_id"
  }
}

run "custom_subnet_skips_subnet_lookup" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
    vpc_id    = "vpc-custom123"
    subnet_id = "subnet-custom456"
  }

  assert {
    condition     = length(data.aws_subnets.default) == 0
    error_message = "Should not look up subnets when subnet_id is provided"
  }
}

run "custom_vpc_without_subnet_still_looks_up_subnets" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
    vpc_id    = "vpc-custom123"
  }

  assert {
    condition     = length(data.aws_subnets.default) == 1
    error_message = "Should still look up subnets when only vpc_id is provided (no subnet_id)"
  }
}
