resource "aws_iam_user" "gha_user" {
  name = "gha-deploybot"
}

resource "aws_iam_access_key" "gha_user_key" {
  user = aws_iam_user.gha_user.name
}

resource "aws_ssm_parameter" "gha_user_id" {
  name  = "${var.projectname}-gha-user-id"
  type  = "SecureString"
  value = aws_iam_access_key.gha_user_key.id
}

resource "aws_ssm_parameter" "gha_user_secret" {
  name  = "${var.projectname}-gha-user-secret"
  type  = "SecureString"
  value = aws_iam_access_key.gha_user_key.secret
}

resource "aws_iam_policy" "gha_policy" {
  name        = "my-example-policy"
  description = "A policy for example user"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "lambda:UpdateFunctionCode"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "gha_policy_attachment" {
  user       = aws_iam_user.gha_user.name
  policy_arn = aws_iam_policy.gha_policy.arn
}
