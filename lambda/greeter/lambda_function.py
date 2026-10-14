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

# Longest name echoed back, so a caller cannot make the function return or log a huge string.
MAX_NAME_LENGTH = 64


def _clean(name):
    """A trimmed, length-limited string, or "unknown" for anything that is not a usable name."""
    if not isinstance(name, str) or not name.strip():
        return "unknown"
    return name.strip()[:MAX_NAME_LENGTH]


def _extract_name(event):
    """Return the name from any of the three event shapes the lab uses."""
    if not isinstance(event, dict):
        return "unknown"
    if "name" in event:
        return _clean(event["name"])

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
        return _clean(parsed.get("name"))

    return "unknown"


def _source(event):
    """Which of the three invocation shapes this is, for the log line."""
    if not isinstance(event, dict):
        return "other"
    if "requestContext" in event:
        return "http"
    return "direct"


def lambda_handler(event, context):
    name = _extract_name(event)
    # Log the shape, not the event: HTTP events carry the caller's IP address and headers.
    print(json.dumps({"source": _source(event), "name_length": len(name)}))

    message = f"Hello {name}!"

    return {
        "statusCode": 200,
        "headers": {"content-type": "text/plain"},
        "body": message,
    }
