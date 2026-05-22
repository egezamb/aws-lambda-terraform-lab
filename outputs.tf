output "ec2_instance_id" {
  description = "ID of the test EC2 instance targeted by the scheduled Lambda"
  value       = aws_instance.lab_test.id
}

output "ec2_instance_state_url" {
  description = "AWS Console deep link to the test EC2 instance"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/ec2/home?region=${data.aws_region.current.name}#InstanceDetails:instanceId=${aws_instance.lab_test.id}"
}

output "ec2_stopper_lambda_name" {
  description = "Name of the scheduled EC2 stopper Lambda (Exercise 1)"
  value       = aws_lambda_function.ec2_stopper.function_name
}

output "schedule_name" {
  description = "Name of the EventBridge Scheduler firing every 2 minutes"
  value       = aws_scheduler_schedule.stop_ec2.name
}

output "greeter_lambda_name" {
  description = "Name of the greeter Lambda (Exercises 2 and 3)"
  value       = aws_lambda_function.greeter.function_name
}

output "greeter_function_url" {
  description = "Public Function URL for the greeter Lambda — POST a JSON body with {\"name\": \"...\"}"
  value       = aws_lambda_function_url.greeter.function_url
}

output "greeter_http_api_endpoint" {
  description = "HTTP API endpoint for the greeter Lambda — POST {\"name\": \"...\"} to /greet"
  value       = "${aws_apigatewayv2_api.greeter_http.api_endpoint}/greet"
}

output "greeter_rest_api_endpoint" {
  description = "REST API endpoint for the greeter Lambda — GET ?name=<your-name>"
  value       = "${aws_api_gateway_stage.greeter_rest_default.invoke_url}/myFun2"
}

output "sample_curl_function_url" {
  description = "Copy-paste curl command to invoke the Function URL"
  value       = "curl -H 'content-type: application/json' -d '{\"name\":\"${var.your_name}\"}' ${aws_lambda_function_url.greeter.function_url}"
}

output "sample_curl_http_api" {
  description = "Copy-paste curl command to invoke the HTTP API"
  value       = "curl -H 'content-type: application/json' -d '{\"name\":\"${var.your_name}\"}' ${aws_apigatewayv2_api.greeter_http.api_endpoint}/greet"
}

output "sample_curl_rest_api" {
  description = "Copy-paste curl command to invoke the REST API"
  value       = "curl '${aws_api_gateway_stage.greeter_rest_default.invoke_url}/myFun2?name=${var.your_name}'"
}
