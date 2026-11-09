"""Tests for the greeter Lambda: the three event shapes the lab uses, and bad input."""

import importlib.util
import json
from pathlib import Path

import pytest

_path = Path(__file__).resolve().parent.parent / "lambda" / "greeter" / "lambda_function.py"
_spec = importlib.util.spec_from_file_location("greeter", _path)
greeter = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(greeter)


def body(event):
    return greeter.lambda_handler(event, None)["body"]


@pytest.mark.parametrize(
    "event",
    [
        {"name": "Ada"},  # direct test event
        {"body": json.dumps({"name": "Ada"})},  # Function URL / HTTP API
        {"requestContext": {}, "body": json.dumps({"name": "Ada"})},  # REST API with mapping
    ],
)
def test_the_three_event_shapes(event):
    assert body(event) == "Hello Ada!"


@pytest.mark.parametrize(
    "event",
    [{}, {"name": 5}, {"name": "   "}, {"body": "not json"}, {"body": json.dumps([1, 2])}, [], None],
)
def test_bad_input_is_unknown(event):
    assert body(event) == "Hello unknown!"


def test_long_names_are_cut():
    assert body({"name": "A" * 500}) == "Hello " + "A" * greeter.MAX_NAME_LENGTH + "!"


def test_the_event_is_not_logged(capsys):
    greeter.lambda_handler({"requestContext": {"http": {"sourceIp": "203.0.113.7"}}, "body": "{}"}, None)
    logged = capsys.readouterr().out
    assert "203.0.113.7" not in logged
    assert json.loads(logged) == {"source": "http", "name_length": len("unknown")}

def test_base64_json_body():
    import base64
    encoded = base64.b64encode(json.dumps({"name": "Çağla"}).encode()).decode()
    assert body({"body": encoded, "isBase64Encoded": True}) == "Hello Çağla!"

@pytest.mark.parametrize("encoded", ["!invalid!", "/w==", {}, "e30="])
def test_bad_base64_payloads_are_safe(encoded):
    assert body({"body": encoded, "isBase64Encoded": True}) == "Hello unknown!"

def test_query_string_greeting():
    assert body({"queryStringParameters": {"name": "O'Reilly"}, "body": None}) == "Hello O'Reilly!"

@pytest.mark.parametrize("query", [None, [], "name=Ada", {"name": 42}])
def test_malformed_query_parameters(query):
    assert body({"queryStringParameters": query}) == "Hello unknown!"

def test_direct_name_takes_precedence_over_query_and_body():
    assert body({"name": "Ada", "queryStringParameters": {"name": "Grace"}, "body": '{"name":"Linus"}'}) == "Hello Ada!"

@pytest.mark.parametrize("name,expected", [("Ada\r\n", "Ada"), ("A\x00da", "Ada"), ("\x1b\n", "unknown"), ("Çağla", "Çağla")])
def test_control_characters_are_removed(name, expected):
    assert body({"name": name}) == f"Hello {expected}!"

def test_oversized_body_is_not_parsed():
    assert body({"body": json.dumps({"name": "Ada", "padding": "x" * greeter.MAX_BODY_LENGTH})}) == "Hello unknown!"

def test_deeply_nested_json_is_safe():
    assert body({"body": "[" * 2000 + "0" + "]" * 2000}) == "Hello unknown!"

def test_personalized_response_headers():
    response = greeter.lambda_handler({"name": "Çağla"}, None)
    assert response["headers"] == {
        "content-type": "text/plain; charset=utf-8",
        "cache-control": "no-store",
        "x-content-type-options": "nosniff",
    }
