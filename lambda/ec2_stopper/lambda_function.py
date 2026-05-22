"""
Lab 10 - Exercise 1: EC2 stopper Lambda.

Triggered on a schedule by EventBridge Scheduler. Stops the configured
EC2 instances in the configured region.

Notes:
- Region and instance IDs come from environment variables (set by Terraform)
  rather than hard-coded as in the lab spec. This makes the function
  redeployable to any region without code changes.
- Calling stop_instances on already-stopped instances is idempotent: AWS
  returns a successful response and the instance state stays Stopped.
"""

import json
import os

import boto3

REGION = os.environ.get("TARGET_REGION", "us-east-1")
INSTANCE_IDS = [
    instance_id.strip()
    for instance_id in os.environ.get("TARGET_INSTANCE_IDS", "").split(",")
    if instance_id.strip()
]

ec2 = boto3.client("ec2", region_name=REGION)


def lambda_handler(event, context):
    """Stop all configured EC2 instances and return a structured summary."""
    if not INSTANCE_IDS:
        message = "No TARGET_INSTANCE_IDS configured. Nothing to do."
        print(message)
        return {"statusCode": 400, "body": message}

    response = ec2.stop_instances(InstanceIds=INSTANCE_IDS)

    stopped = [
        {
            "instance_id": item["InstanceId"],
            "previous_state": item["PreviousState"]["Name"],
            "current_state": item["CurrentState"]["Name"],
        }
        for item in response.get("StoppingInstances", [])
    ]

    summary = {
        "statusCode": 200,
        "region": REGION,
        "stopped": stopped,
    }
    print(json.dumps(summary))
    return summary
