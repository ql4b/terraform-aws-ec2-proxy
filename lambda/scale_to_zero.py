"""
Scale-to-zero handler for terraform-aws-ec2-proxy (experimental use_asg mode).

Triggered by an EventBridge rule matching EC2 "shutting-down" state-change
events. For each terminating instance we:

  1. Read the instance's tags.
  2. Gate on the module's ownership tag (proxy:managed-by == MANAGED_BY value);
     ignore instances that don't belong to this deployment.
  3. Read the ASG name from the auto-injected aws:autoscaling:groupName tag.
  4. Set that ASG's desired capacity to 0 so the ASG does NOT relaunch a
     replacement. Matching on "shutting-down" (rather than "terminated") is
     deliberate: it shrinks the window in which the ASG could observe
     running < desired and launch a replacement before we scale to zero.

The function is intentionally defensive: a missing tag, a foreign instance, or
an instance not managed by an ASG is a clean no-op, never an error.
"""

import os

import boto3

MANAGED_BY_KEY = "proxy:managed-by"
ASG_TAG_KEY = "aws:autoscaling:groupName"

ec2 = boto3.client("ec2")
autoscaling = boto3.client("autoscaling")


def _tags_for(instance_id):
    """Return {key: value} tags for an instance id, or {} if not found."""
    resp = ec2.describe_instances(InstanceIds=[instance_id])
    for reservation in resp.get("Reservations", []):
        for instance in reservation.get("Instances", []):
            return {t["Key"]: t["Value"] for t in instance.get("Tags", [])}
    return {}


def handler(event, _context):
    expected = os.environ.get("MANAGED_BY")
    instance_id = event.get("detail", {}).get("instance-id")

    if not instance_id:
        print("no instance-id in event; ignoring")
        return

    tags = _tags_for(instance_id)

    # Ownership gate: only act on instances this module deployment created.
    if tags.get(MANAGED_BY_KEY) != expected:
        print(
            f"instance {instance_id} not managed by '{expected}' "
            f"(tag={tags.get(MANAGED_BY_KEY)!r}); ignoring"
        )
        return

    asg_name = tags.get(ASG_TAG_KEY)
    if not asg_name:
        print(f"instance {instance_id} has no ASG tag; nothing to scale")
        return

    print(f"instance {instance_id} shutting down; setting ASG {asg_name} desired=0")
    autoscaling.set_desired_capacity(
        AutoScalingGroupName=asg_name,
        DesiredCapacity=0,
        HonorCooldown=False,
    )
    print(f"ASG {asg_name} desired capacity set to 0")
