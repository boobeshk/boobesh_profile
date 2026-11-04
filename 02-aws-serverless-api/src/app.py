"""Items API: a minimal CRUD Lambda behind an API Gateway HTTP API (payload v2.0)."""

import json
import os
import uuid

import boto3

TABLE = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def _response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def list_items(_event):
    return _response(200, TABLE.scan(Limit=100).get("Items", []))


def create_item(event):
    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Body must be valid JSON."})
    name = str(payload.get("name", "")).strip()
    if not name:
        return _response(400, {"error": "Field 'name' is required."})
    item = {"id": str(uuid.uuid4()), "name": name}
    TABLE.put_item(Item=item)
    return _response(201, item)


def get_item(event):
    item = TABLE.get_item(Key={"id": event["pathParameters"]["id"]}).get("Item")
    return _response(200, item) if item else _response(404, {"error": "Not found."})


def delete_item(event):
    TABLE.delete_item(Key={"id": event["pathParameters"]["id"]})
    return {"statusCode": 204}


ROUTES = {
    "GET /items": list_items,
    "POST /items": create_item,
    "GET /items/{id}": get_item,
    "DELETE /items/{id}": delete_item,
}


def handler(event, _context):
    route = ROUTES.get(event.get("routeKey"))
    if route is None:
        return _response(404, {"error": "Unknown route."})
    return route(event)
