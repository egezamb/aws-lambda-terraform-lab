data "archive_file" "greeter_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/greeter/lambda_function.py"
  output_path = "${path.module}/lambda/greeter/lambda_function.zip"
}

resource "aws_lambda_function" "greeter" {
  function_name = "${var.project_name}-myFun2"
  description   = "Lab 10 Exercises 2 and 3: greeter microservice"

  role     = data.aws_iam_role.lab_role.arn
  runtime  = var.lambda_runtime
  handler  = "lambda_function.lambda_handler"
  timeout  = 10
  filename = data.archive_file.greeter_zip.output_path

  source_code_hash = data.archive_file.greeter_zip.output_base64sha256

  tags = {
    Exercise = "2 and 3 - Greeter microservice"
  }
}

resource "aws_cloudwatch_log_group" "greeter" {
  name              = "/aws/lambda/${aws_lambda_function.greeter.function_name}"
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

resource "aws_lambda_permission" "allow_function_url" {
  statement_id           = "AllowPublicFunctionUrlInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.greeter.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}
