data "archive_file" "ec2_stopper_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/ec2_stopper/lambda_function.py"
  output_path = "${path.module}/lambda/ec2_stopper/lambda_function.zip"
}

resource "aws_lambda_function" "ec2_stopper" {
  function_name = "${var.project_name}-myFun1"
  description   = "Lab 10 Exercise 1: Stops the test EC2 instance on a schedule"

  role     = data.aws_iam_role.lab_role.arn
  runtime  = var.lambda_runtime
  handler  = "lambda_function.lambda_handler"
  timeout  = 30
  filename = data.archive_file.ec2_stopper_zip.output_path

  source_code_hash = data.archive_file.ec2_stopper_zip.output_base64sha256

  environment {
    variables = {
      TARGET_REGION       = data.aws_region.current.name
      TARGET_INSTANCE_IDS = aws_instance.lab_test.id
    }
  }

  tags = {
    Exercise = "1 - Scheduled Lambda"
  }
}

resource "aws_cloudwatch_log_group" "ec2_stopper" {
  name              = "/aws/lambda/${aws_lambda_function.ec2_stopper.function_name}"
  retention_in_days = var.log_retention_days
}
