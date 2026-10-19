# Terraform tests with a mocked AWS provider: no AWS account or credentials needed.
#   terraform init -backend=false && terraform test
# "apply" here only applies to the mock, so computed values (ARNs, IDs) are known and can be
# compared. The archive provider is real: it zips lambda/ locally.

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
  mock_data "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/LabRole"
    }
  }
  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }
  # The provider checks ARNs on apply, and the mock's random strings aren't ARNs.
  mock_resource "aws_scheduler_schedule" {
    defaults = {
      arn = "arn:aws:scheduler:us-east-1:123456789012:schedule/default/mock"
    }
  }
  mock_resource "aws_apigatewayv2_api" {
    defaults = {
      execution_arn = "arn:aws:execute-api:us-east-1:123456789012:httpapi"
    }
  }
  mock_resource "aws_api_gateway_rest_api" {
    defaults = {
      execution_arn = "arn:aws:execute-api:us-east-1:123456789012:restapi"
    }
  }
}

# A different ARN for each function, so a test can tell which one a schedule or permission names.
override_resource {
  target = aws_lambda_function.ec2_stopper
  values = {
    arn = "arn:aws:lambda:us-east-1:123456789012:function:lab10-lambda-ec2-stopper"
  }
}

override_resource {
  target = aws_lambda_function.greeter
  values = {
    arn = "arn:aws:lambda:us-east-1:123456789012:function:lab10-lambda-greeter"
  }
}

run "each_lambda_logs_to_its_own_group_with_retention" {
  command = apply

  assert {
    condition     = aws_cloudwatch_log_group.ec2_stopper.name == "/aws/lambda/${aws_lambda_function.ec2_stopper.function_name}"
    error_message = "The stopper's log group must be the one Lambda writes to, or Lambda makes its own without retention."
  }
  assert {
    condition     = aws_cloudwatch_log_group.greeter.name == "/aws/lambda/${aws_lambda_function.greeter.function_name}"
    error_message = "The greeter's log group must be the one Lambda writes to."
  }
  assert {
    condition     = aws_cloudwatch_log_group.ec2_stopper.retention_in_days == 7 && aws_cloudwatch_log_group.greeter.retention_in_days == 7
    error_message = "Both log groups keep logs for log_retention_days (7 by default)."
  }
}

run "log_retention_days_reaches_both_groups" {
  command = plan

  variables {
    log_retention_days = 30
  }

  assert {
    condition     = aws_cloudwatch_log_group.ec2_stopper.retention_in_days == 30 && aws_cloudwatch_log_group.greeter.retention_in_days == 30
    error_message = "log_retention_days must set both groups' retention."
  }
}

run "the_stopper_targets_only_the_lab_instance" {
  command = apply

  assert {
    condition     = aws_lambda_function.ec2_stopper.environment[0].variables["TARGET_INSTANCE_IDS"] == aws_instance.lab_test.id
    error_message = "The stopper may only stop the lab's own test instance."
  }
}

run "the_schedule_invokes_the_stopper_without_retries" {
  command = apply

  assert {
    condition     = aws_scheduler_schedule.stop_ec2.target[0].arn == aws_lambda_function.ec2_stopper.arn
    error_message = "The schedule must invoke the stopper."
  }
  assert {
    condition     = aws_scheduler_schedule.stop_ec2.target[0].retry_policy[0].maximum_retry_attempts == 0
    error_message = "A missed run is not retried; the next one comes in schedule_rate anyway."
  }
  assert {
    condition     = aws_scheduler_schedule.stop_ec2.schedule_expression == "rate(2 minutes)"
    error_message = "The default schedule is rate(2 minutes)."
  }
}

run "lambda_permissions_are_scoped_to_their_source" {
  command = apply

  assert {
    condition = (
      aws_lambda_permission.allow_scheduler.principal == "scheduler.amazonaws.com" &&
      aws_lambda_permission.allow_scheduler.source_arn == aws_scheduler_schedule.stop_ec2.arn
    )
    error_message = "Only this schedule may invoke the stopper."
  }
  assert {
    condition     = aws_lambda_permission.allow_http_api.source_arn == "${aws_apigatewayv2_api.greeter_http.execution_arn}/*/*"
    error_message = "Only this HTTP API may invoke the greeter through API Gateway v2."
  }
  assert {
    condition     = aws_lambda_permission.allow_rest_api.source_arn == "${aws_api_gateway_rest_api.greeter_rest.execution_arn}/*/*"
    error_message = "Only this REST API may invoke the greeter through API Gateway v1."
  }
}

run "the_public_function_url_has_both_statements_it_needs" {
  command = plan

  assert {
    condition = (
      aws_lambda_permission.allow_function_url.action == "lambda:InvokeFunctionUrl" &&
      aws_lambda_permission.allow_function_url.function_url_auth_type == "NONE"
    )
    error_message = "The function URL needs lambda:InvokeFunctionUrl for auth type NONE."
  }
  assert {
    condition = (
      aws_lambda_permission.allow_function_url_invoke.action == "lambda:InvokeFunction" &&
      aws_lambda_permission.allow_function_url_invoke.invoked_via_function_url
    )
    error_message = "New function URLs also need lambda:InvokeFunction, limited to calls through the URL."
  }
}

run "the_ami_filter_only_matches_the_standard_al2023_image" {
  command = plan

  assert {
    condition = anytrue([
      for f in data.aws_ami.amazon_linux_2023.filter :
      f.name == "name" && contains(f.values, "al2023-ami-2023.*-x86_64")
    ])
    error_message = "The name filter must exclude the minimal and ECS-optimized AL2023 images."
  }
}
