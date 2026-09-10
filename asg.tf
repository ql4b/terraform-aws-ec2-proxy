# ---------------------------------------------------------------------------
# Experimental: Auto Scaling Group proxy management (var.use_asg = true)
#
# Instead of a standalone instance, the proxy runs as a single-instance ASG
# backed by the shared aws_launch_template.proxy. The ttl_hours "shutdown -h"
# still terminates the instance; an EventBridge rule + Lambda then set the
# ASG's desired capacity to 0 so no replacement is launched. Terraform ignores
# desired_capacity, so the out-of-band scaling never shows up as drift.
#
# A wrapper (out of scope for this module) scales the ASG back to 1 to hand
# out a fresh proxy (and a fresh public IP) on demand.
# ---------------------------------------------------------------------------

locals {
  asg_enabled = var.use_asg
}

resource "aws_autoscaling_group" "proxy" {
  count = local.asg_enabled ? 1 : 0

  name                = module.this.id
  vpc_zone_identifier = [local.subnet_id]

  min_size         = 0
  max_size         = 1
  desired_capacity = 1

  # Instances are considered replaceable; give user_data time to install Squid.
  health_check_type         = "EC2"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.proxy.id
    version = aws_launch_template.proxy.latest_version
  }

  dynamic "tag" {
    for_each = local.instance_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # desired_capacity is managed out-of-band: the scale-to-zero Lambda drives it
  # to 0 on TTL shutdown, and the wrapper drives it back to 1 on demand.
  # Ignoring it keeps Terraform from fighting those changes (no drift).
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# --- Scale-to-zero: EventBridge rule + Lambda -------------------------------

data "archive_file" "scale_to_zero" {
  count       = local.asg_enabled ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/lambda/scale_to_zero.py"
  output_path = "${path.module}/lambda/scale_to_zero.zip"
}

resource "aws_iam_role" "scale_to_zero" {
  count = local.asg_enabled ? 1 : 0
  name  = "${module.this.id}-scale-to-zero"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = module.this.tags
}

resource "aws_iam_role_policy" "scale_to_zero" {
  count = local.asg_enabled ? 1 : 0
  name  = "${module.this.id}-scale-to-zero"
  role  = aws_iam_role.scale_to_zero[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Describe* calls are not resource-scopable.
        Sid      = "ReadInstanceTags"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        Sid      = "ScaleTargetAsg"
        Effect   = "Allow"
        Action   = ["autoscaling:SetDesiredCapacity"]
        Resource = aws_autoscaling_group.proxy[0].arn
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

resource "aws_lambda_function" "scale_to_zero" {
  #checkov:skip=CKV_AWS_115:Reserved concurrency unnecessary for a disposable proxy
  #checkov:skip=CKV_AWS_116:No DLQ; a missed scale-down self-heals on the next cycle
  #checkov:skip=CKV_AWS_117:VPC config unnecessary; only calls public AWS APIs
  #checkov:skip=CKV_AWS_173:No sensitive env vars; MANAGED_BY is a non-secret tag value
  #checkov:skip=CKV_AWS_272:Code signing unnecessary for an inline experimental function
  count = local.asg_enabled ? 1 : 0

  function_name = "${module.this.id}-scale-to-zero"
  role          = aws_iam_role.scale_to_zero[0].arn
  handler       = "scale_to_zero.handler"
  runtime       = "python3.12"
  timeout       = 30

  filename         = data.archive_file.scale_to_zero[0].output_path
  source_code_hash = data.archive_file.scale_to_zero[0].output_base64sha256

  environment {
    variables = {
      MANAGED_BY = module.this.id
    }
  }

  tags = module.this.tags
}

resource "aws_cloudwatch_event_rule" "instance_shutting_down" {
  count       = local.asg_enabled ? 1 : 0
  name        = "${module.this.id}-instance-shutting-down"
  description = "Fires when an EC2 instance begins shutting down; scale-to-zero Lambda filters by tag."

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["shutting-down"]
    }
  })

  tags = module.this.tags
}

resource "aws_cloudwatch_event_target" "scale_to_zero" {
  count     = local.asg_enabled ? 1 : 0
  rule      = aws_cloudwatch_event_rule.instance_shutting_down[0].name
  target_id = "scale-to-zero"
  arn       = aws_lambda_function.scale_to_zero[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count         = local.asg_enabled ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_to_zero[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.instance_shutting_down[0].arn
}
