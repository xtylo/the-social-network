# API Gateway HTTP API: the single public entry point. It routes by path:
#   GET /recommendations/{userId} -> Rust Lambda
#   everything else ($default)    -> Node Lambda

resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  # Guardrail for the budget: API Gateway rejects traffic above this with 429.
  default_route_settings {
    throttling_rate_limit  = 300
    throttling_burst_limit = 500
  }
}

resource "aws_apigatewayv2_integration" "reco" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.reco.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "api" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "recommendations" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /recommendations/{userId}"
  target    = "integrations/${aws_apigatewayv2_integration.reco.id}"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.api.id}"
}

# Lets API Gateway invoke each Lambda.
resource "aws_lambda_permission" "reco" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reco.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
