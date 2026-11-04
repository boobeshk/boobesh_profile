"""Stops or starts EC2 instances that opt in with a tag (default Schedule=office-hours).

Invoked by EventBridge with {"action": "stop"} in the evening and {"action": "start"} in the morning.
"""

import os

import boto3

EC2 = boto3.client("ec2")
TAG_KEY = os.environ.get("TAG_KEY", "Schedule")
TAG_VALUE = os.environ.get("TAG_VALUE", "office-hours")

# Only touch instances in the state the action applies to.
SOURCE_STATE = {"stop": "running", "start": "stopped"}


def find_instances(state):
    ids = []
    paginator = EC2.get_paginator("describe_instances")
    pages = paginator.paginate(
        Filters=[
            {"Name": f"tag:{TAG_KEY}", "Values": [TAG_VALUE]},
            {"Name": "instance-state-name", "Values": [state]},
        ]
    )
    for page in pages:
        for reservation in page["Reservations"]:
            ids.extend(i["InstanceId"] for i in reservation["Instances"])
    return ids


def handler(event, _context):
    action = event.get("action")
    if action not in SOURCE_STATE:
        raise ValueError(f"Unknown action {action!r}; expected 'stop' or 'start'.")

    ids = find_instances(SOURCE_STATE[action])
    if ids:
        if action == "stop":
            EC2.stop_instances(InstanceIds=ids)
        else:
            EC2.start_instances(InstanceIds=ids)

    print(f"{action}: {len(ids)} instance(s) {ids}")
    return {"action": action, "instances": ids}
