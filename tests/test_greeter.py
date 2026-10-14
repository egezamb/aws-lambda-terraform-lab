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
