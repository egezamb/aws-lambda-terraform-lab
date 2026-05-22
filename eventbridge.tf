resource "aws_scheduler_schedule" "stop_ec2" {
  name        = "${var.project_name}-stop-ec2-schedule"
  description = "Lab 10 Exercise 1: invokes the EC2 stopper Lambda every ${var.schedule_rate}"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.schedule_rate
  schedule_expression_timezone = "UTC"

  target {
    arn      = aws_lambda_function.ec2_stopper.arn
    role_arn = data.aws_iam_role.lab_role.arn

    retry_policy {
      maximum_retry_attempts       = 0
      maximum_event_age_in_seconds = 60
    }
  }
}

resource "aws_lambda_permission" "allow_scheduler" {
  statement_id  = "AllowEventBridgeSchedulerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_stopper.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.stop_ec2.arn
}
