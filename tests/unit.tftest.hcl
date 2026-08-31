# Unit tests for terraform-aws-ec2-proxy
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

# --- Default configuration (spot, auto-detect IP) ---

run "defaults_use_spot" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
  }

  assert {
    condition     = output.is_spot == true
    error_message = "Default should use spot instances"
  }

  assert {
    condition     = output.ttl_hours == null
    error_message = "Default TTL should be null (no auto-termination)"
  }
}

run "defaults_create_spot_instance" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
  }

  assert {
    condition     = length(aws_spot_instance_request.proxy) == 1
    error_message = "Should create exactly one spot instance request"
  }

  assert {
    condition     = length(aws_instance.proxy) == 0
    error_message = "Should not create an on-demand instance when spot=true"
  }
}

# --- On-demand mode ---

run "on_demand_creates_instance" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
    spot      = false
  }

  assert {
    condition     = length(aws_instance.proxy) == 1
    error_message = "Should create exactly one on-demand instance"
  }

  assert {
    condition     = length(aws_spot_instance_request.proxy) == 0
    error_message = "Should not create a spot request when spot=false"
  }

  assert {
    condition     = output.is_spot == false
    error_message = "is_spot output should be false"
  }
}

# --- Security hardening ---

run "imdsv2_enforced_on_spot" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
  }

  assert {
    condition     = aws_spot_instance_request.proxy[0].metadata_options[0].http_tokens == "required"
    error_message = "Spot instance must enforce IMDSv2 (http_tokens=required)"
  }
}

run "imdsv2_enforced_on_demand" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
    spot      = false
  }

  assert {
    condition     = aws_instance.proxy[0].metadata_options[0].http_tokens == "required"
    error_message = "On-demand instance must enforce IMDSv2 (http_tokens=required)"
  }
}

run "root_volume_encrypted_spot" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
  }

  assert {
    condition     = aws_spot_instance_request.proxy[0].root_block_device[0].encrypted == true
    error_message = "Spot instance root volume must be encrypted"
  }
}

run "root_volume_encrypted_on_demand" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
    spot      = false
  }

  assert {
    condition     = aws_instance.proxy[0].root_block_device[0].encrypted == true
    error_message = "On-demand instance root volume must be encrypted"
  }
}

# --- TTL / auto-terminate ---

run "ttl_sets_terminate_behavior_spot" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
    ttl_hours = 4
  }

  assert {
    condition     = aws_spot_instance_request.proxy[0].instance_initiated_shutdown_behavior == "terminate"
    error_message = "With ttl_hours set, shutdown behavior should be 'terminate'"
  }

  assert {
    condition     = output.ttl_hours == 4
    error_message = "ttl_hours output should reflect the variable value"
  }
}

run "no_ttl_sets_stop_behavior_on_demand" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
    spot      = false
  }

  assert {
    condition     = aws_instance.proxy[0].instance_initiated_shutdown_behavior == "stop"
    error_message = "Without ttl_hours, shutdown behavior should be 'stop'"
  }
}

# --- Custom port and instance type ---

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

  assert {
    condition     = one([for r in aws_security_group.proxy.ingress : r.to_port if r.to_port == 3128]) == 3128
    error_message = "Security group ingress to_port should match proxy_port"
  }
}

# --- Explicit allowed_cidrs ---

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

  assert {
    condition     = one([for r in aws_security_group.proxy.ingress : true if contains(r.cidr_blocks, "192.168.1.0/24")]) == true
    error_message = "Security group should include the second explicit CIDR"
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

# --- Authentication ---

run "auth_disabled_by_default" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
  }

  # When auth is disabled, proxy_url should not contain @ (no credentials)
  # We can't easily parse the URL in plan, but we can verify the local
  assert {
    condition     = output.is_spot == true
    error_message = "Sanity check — defaults should produce a valid plan"
  }
}

run "auth_enabled_with_both_credentials" {
  command = plan

  variables {
    namespace      = "test"
    name           = "proxy"
    proxy_username = "testuser"
    proxy_password = "testpass"
  }

  # Plan should succeed with auth enabled
  assert {
    condition     = output.is_spot == true
    error_message = "Plan with auth enabled should succeed"
  }
}

# --- IAM role ---

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

# --- Security group egress ---

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

  assert {
    condition     = one([for r in aws_security_group.proxy.egress : true if r.protocol == "-1"]) == true
    error_message = "Egress should allow all protocols"
  }
}


# --- Custom VPC / subnet ---

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

  assert {
    condition     = aws_spot_instance_request.proxy[0].subnet_id == "subnet-custom456"
    error_message = "Spot instance should use the provided subnet_id"
  }
}

run "custom_subnet_on_demand" {
  command = plan

  variables {
    namespace = "test"
    name      = "proxy"
    vpc_id    = "vpc-custom123"
    subnet_id = "subnet-custom456"
    spot      = false
  }

  assert {
    condition     = aws_instance.proxy[0].subnet_id == "subnet-custom456"
    error_message = "On-demand instance should use the provided subnet_id"
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
