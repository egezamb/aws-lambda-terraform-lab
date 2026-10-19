locals {
  greeter_name = "${var.project_name}-myFun2"
}

data "archive_file" "greeter_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/greeter/lambda_function.py"
  output_path = "${path.module}/lambda/greeter/lambda_function.zip"
}

resource "aws_lambda_function" "greeter" {
  function_name = local.greeter_name
  description   = "Lab 10 Exercises 2 and 3: greeter microservice"

  role     = data.aws_iam_role.lab_role.arn
  runtime  = var.lambda_runtime
  handler  = "lambda_function.lambda_handler"
  timeout  = 10
  filename = data.archive_file.greeter_zip.output_path

  source_code_hash = data.archive_file.greeter_zip.output_base64sha256

  depends_on = [aws_cloudwatch_log_group.greeter]

  tags = {
    Exercise = "2 and 3 - Greeter microservice"
  }
}

# Named from the local, not from the function, so it exists before the function's first run. If
# Lambda ran first it would create the group itself, and the next apply would fail with
# ResourceAlreadyExistsException (and the group would have no retention).
resource "aws_cloudwatch_log_group" "greeter" {
  name              = "/aws/lambda/${local.greeter_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function_url" "greeter" {
  function_name      = aws_lambda_function.greeter.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["POST", "GET"]
    allow_headers = ["content-type"]
  }
}

# A public function URL needs two statements: InvokeFunctionUrl, and (for URLs created since
# October 2025) InvokeFunction. Without the second the URL answers 403 Forbidden.
resource "aws_lambda_permission" "allow_function_url" {
  statement_id           = "AllowPublicFunctionUrlInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.greeter.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

# invoked_via_function_url limits this statement to calls through the URL, so the public "*"
# principal cannot invoke the function directly with the Lambda API.
resource "aws_lambda_permission" "allow_function_url_invoke" {
  statement_id             = "AllowPublicFunctionUrlInvokeFunction"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.greeter.function_name
  principal                = "*"
  invoked_via_function_url = true
}
