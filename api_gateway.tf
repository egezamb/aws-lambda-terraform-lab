resource "aws_apigatewayv2_api" "greeter_http" {
  name          = "${var.project_name}-myFun2-http-api"
  description   = "Lab 10 Exercise 3: HTTP API in front of the greeter Lambda"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "GET"]
    allow_headers = ["content-type"]
  }
}

resource "aws_apigatewayv2_integration" "greeter_http" {
  api_id                 = aws_apigatewayv2_api.greeter_http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.greeter.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "greeter_http_default" {
  api_id    = aws_apigatewayv2_api.greeter_http.id
  route_key = "POST /greet"
  target    = "integrations/${aws_apigatewayv2_integration.greeter_http.id}"
}

resource "aws_apigatewayv2_stage" "greeter_http_default" {
  api_id      = aws_apigatewayv2_api.greeter_http.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_http_api" {
  statement_id  = "AllowHttpApiInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.greeter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.greeter_http.execution_arn}/*/*"
}

resource "aws_api_gateway_rest_api" "greeter_rest" {
  name        = "${var.project_name}-myFun2-rest-api"
  description = "Lab 10 Exercise 3: REST API with GET + query string + mapping template"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "greeter_rest_path" {
  rest_api_id = aws_api_gateway_rest_api.greeter_rest.id
  parent_id   = aws_api_gateway_rest_api.greeter_rest.root_resource_id
  path_part   = "myFun2"
}

resource "aws_api_gateway_method" "greeter_rest_get" {
  rest_api_id   = aws_api_gateway_rest_api.greeter_rest.id
  resource_id   = aws_api_gateway_resource.greeter_rest_path.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.querystring.name" = true
  }
}

resource "aws_api_gateway_integration" "greeter_rest_get" {
  rest_api_id             = aws_api_gateway_rest_api.greeter_rest.id
  resource_id             = aws_api_gateway_resource.greeter_rest_path.id
  http_method             = aws_api_gateway_method.greeter_rest_get.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.greeter.invoke_arn
  passthrough_behavior    = "WHEN_NO_TEMPLATES"

  request_templates = {
    "application/json" = jsonencode({
      body = "{\"name\":\"$input.params('name')\"}"
    })
  }
}

resource "aws_api_gateway_method_response" "greeter_rest_get_200" {
  rest_api_id = aws_api_gateway_rest_api.greeter_rest.id
  resource_id = aws_api_gateway_resource.greeter_rest_path.id
  http_method = aws_api_gateway_method.greeter_rest_get.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "greeter_rest_get_200" {
  rest_api_id = aws_api_gateway_rest_api.greeter_rest.id
  resource_id = aws_api_gateway_resource.greeter_rest_path.id
  http_method = aws_api_gateway_method.greeter_rest_get.http_method
  status_code = aws_api_gateway_method_response.greeter_rest_get_200.status_code

  response_templates = {
    "application/json" = "$input.path('$.body')"
  }

  depends_on = [aws_api_gateway_integration.greeter_rest_get]
}

resource "aws_api_gateway_deployment" "greeter_rest" {
  rest_api_id = aws_api_gateway_rest_api.greeter_rest.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.greeter_rest_path.id,
      aws_api_gateway_method.greeter_rest_get.id,
      aws_api_gateway_integration.greeter_rest_get.id,
      aws_api_gateway_integration_response.greeter_rest_get_200.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "greeter_rest_default" {
  deployment_id = aws_api_gateway_deployment.greeter_rest.id
  rest_api_id   = aws_api_gateway_rest_api.greeter_rest.id
  stage_name    = "default"
}

resource "aws_lambda_permission" "allow_rest_api" {
  statement_id  = "AllowRestApiInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.greeter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.greeter_rest.execution_arn}/*/*"
}
