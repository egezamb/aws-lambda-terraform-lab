"""
Lab 10 - Exercises 2 and 3: Greeter Lambda.

Handles three different invocation shapes safely:

1. Direct test event:        {"name": "Ada"}
2. Function URL / HTTP API:  event["body"] is a JSON string
3. REST API with mapping:    event["body"] is a JSON string (built by the
                              mapping template from query string params)

Returns a Lambda Proxy Integration response: statusCode, headers, body.
"""

import json


def _extract_name(event):
    """Return the name from any of the three event shapes the lab uses."""
    if "name" in event and isinstance(event["name"], str):
        return event["name"]

    body = event.get("body")
    if not body:
        return "unknown"

    try:
        if isinstance(body, str):
            parsed = json.loads(body)
        else:
            parsed = body
    except (json.JSONDecodeError, TypeError):
        return "unknown"

    if isinstance(parsed, dict):
        return parsed.get("name", "unknown")

    return "unknown"


def lambda_handler(event, context):
    print(json.dumps({"event": event}))

    name = _extract_name(event)
    message = f"Hello {name}!"

    return {
        "statusCode": 200,
        "headers": {"content-type": "text/plain"},
        "body": message,
    }
