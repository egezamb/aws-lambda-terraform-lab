"""Tests for the EC2 stopper Lambda, with a fake EC2 client: no AWS account or boto3 needed."""

import importlib.util
import json
import sys
import types
from pathlib import Path

import pytest

_path = Path(__file__).resolve().parent.parent / "lambda" / "ec2_stopper" / "lambda_function.py"


class FakeEC2:
    def __init__(self):
        self.calls = []

    def stop_instances(self, InstanceIds):
        self.calls.append(InstanceIds)
        return {
            "StoppingInstances": [
                {"InstanceId": i, "PreviousState": {"Name": "running"}, "CurrentState": {"Name": "stopping"}}
                for i in InstanceIds
            ]
        }


def load(monkeypatch, instance_ids, region="eu-central-1"):
    """Import the function with the given environment, as Lambda would on a cold start."""
    ec2 = FakeEC2()
    clients = []
    fake_boto3 = types.SimpleNamespace(client=lambda name, region_name: clients.append((name, region_name)) or ec2)
    monkeypatch.setitem(sys.modules, "boto3", fake_boto3)
    monkeypatch.setenv("TARGET_REGION", region)
    monkeypatch.setenv("TARGET_INSTANCE_IDS", instance_ids)
    spec = importlib.util.spec_from_file_location("ec2_stopper", _path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module, ec2, clients


def test_stops_the_configured_instance_in_the_configured_region(monkeypatch):
    stopper, ec2, clients = load(monkeypatch, "i-0abc")
    result = stopper.lambda_handler({}, None)
    assert clients == [("ec2", "eu-central-1")]
    assert ec2.calls == [["i-0abc"]]
    assert result["statusCode"] == 200
    assert result["stopped"] == [{"instance_id": "i-0abc", "previous_state": "running", "current_state": "stopping"}]


def test_a_comma_separated_list_is_trimmed_and_blanks_dropped(monkeypatch):
    stopper, ec2, _ = load(monkeypatch, " i-1 , ,i-2,")
    stopper.lambda_handler({}, None)
    assert ec2.calls == [["i-1", "i-2"]]


@pytest.mark.parametrize("ids", ["", " , "])
def test_no_instances_means_no_call(monkeypatch, ids):
    stopper, ec2, _ = load(monkeypatch, ids)
    result = stopper.lambda_handler({}, None)
    assert ec2.calls == []
    assert result["statusCode"] == 400


def test_the_summary_is_logged_as_one_json_line(monkeypatch, capsys):
    stopper, _, _ = load(monkeypatch, "i-0abc")
    result = stopper.lambda_handler({}, None)
    assert json.loads(capsys.readouterr().out) == result
