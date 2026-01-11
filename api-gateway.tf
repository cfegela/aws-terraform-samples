resource "aws_apigatewayv2_api" "apigw" {
  name          = "${var.projectname}-api-gateway"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.apigw.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "integration" {
  api_id           = aws_apigatewayv2_api.apigw.id
  integration_uri  = aws_lambda_function.sample.invoke_arn
  integration_type = "AWS_PROXY"
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "bedrock-sample" {
  api_id           = aws_apigatewayv2_api.apigw.id
  integration_uri  = aws_lambda_function.bedrock-sample.invoke_arn
  integration_type = "AWS_PROXY"
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "ecs-task-sample" {
  api_id           = aws_apigatewayv2_api.apigw.id
  integration_uri  = aws_lambda_function.ecs-task-sample.invoke_arn
  integration_type = "AWS_PROXY"
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get-all" {
  api_id    = aws_apigatewayv2_api.apigw.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.integration.id}"
}

resource "aws_apigatewayv2_route" "get-one" {
  api_id    = aws_apigatewayv2_api.apigw.id
  route_key = "GET /message/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.integration.id}"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.apigw.id
}

resource "aws_apigatewayv2_route" "bedrock-sample" {
  api_id    = aws_apigatewayv2_api.apigw.id
  route_key = "GET /bedrock"
  target    = "integrations/${aws_apigatewayv2_integration.bedrock-sample.id}"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.apigw.id
}

resource "aws_apigatewayv2_route" "ecs-task-sample" {
  api_id    = aws_apigatewayv2_api.apigw.id
  route_key = "GET /runtask"
  target    = "integrations/${aws_apigatewayv2_integration.ecs-task-sample.id}"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.apigw.id
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sample.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.apigw.execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "bedrock-sample" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bedrock-sample.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.apigw.execution_arn}/*/*/*"
}

resource "aws_apigatewayv2_domain_name" "apigw" {
  domain_name = "api.${var.projectname}.oddball.io"
  domain_name_configuration {
    certificate_arn = var.certarn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "apigw" {
  api_id      = aws_apigatewayv2_api.apigw.id
  domain_name = aws_apigatewayv2_domain_name.apigw.domain_name
  stage       = aws_apigatewayv2_stage.default.id
}

resource "aws_route53_record" "apigw-dns-name" {
  zone_id = var.hostedzoneid
  name    = "api.edgar.oddball.io"
  type    = "CNAME"
  ttl     = 300
  records = [aws_apigatewayv2_domain_name.apigw.domain_name_configuration[0].target_domain_name]
}

resource "aws_cognito_user_pool" "apigw" {
  name = "${var.projectname}-user-pool"
}

resource "aws_cognito_user_pool_client" "apigw" {
  name = "${var.projectname}-user-pool-client"
  user_pool_id = aws_cognito_user_pool.apigw.id
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

resource "aws_apigatewayv2_authorizer" "apigw" {
  api_id           = aws_apigatewayv2_api.apigw.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.projectname}-api-authorizer"
  jwt_configuration {
    audience = [aws_cognito_user_pool_client.apigw.id]
    issuer   = "https://${aws_cognito_user_pool.apigw.endpoint}"
  }
}

resource "random_password" "apigw" {
  length  = 16
  lower   = true
  upper   = true
  special = true
}

resource "aws_ssm_parameter" "apigw" {
  name  = "${var.projectname}-cognito-user-pw"
  type  = "SecureString"
  value = random_password.apigw.result
}

resource "aws_cognito_user" "apigw" {
  user_pool_id = aws_cognito_user_pool.apigw.id
  username     = "edgarpoc"
  password     = random_password.apigw.result
  message_action = "SUPPRESS"
}

# this command confirms the new user:
# aws cognito-idp admin-confirm-sign-up --user-pool-id us-east-2_93VoaVCAj --username edgar.oddball.io
# it should prolly be set up as a local-exec stanza in the aws_cognito_user.apigw resource 

# this command gets the api token from cognito and puts it in an envvar (get password from ssm param store):
# token=$(curl -s --location --request POST 'https://cognito-idp.us-east-2.amazonaws.com' --header 'X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth' --header 'Content-Type: application/x-amz-json-1.1' --data-raw '{"AuthParameters" : {"USERNAME" : "edgarpoc","PASSWORD" : "GETFROMPARAMSTORE"},"AuthFlow" : "USER_PASSWORD_AUTH","ClientId" : "1djjdc5rrps152b2vltec80cmc"}' | jq -r '.AuthenticationResult.IdToken')

# this command hits the protected endpoint:
# curl https://api.edgar.oddball.io/bedrock --header "Authorization: Bearer ${token}"
