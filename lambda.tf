data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_execution_role" {
  name               = "${var.projectname}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "lambda-iam-policy" {
  name = "lambda-iam-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:*",
          "ecs:*",
          "bedrock:*",
          "s3:*",
          "sqs:*",
          "iam:*",
          "logs:*"

        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda-iam-policy-attach" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda-iam-policy.arn
}

data "archive_file" "sample" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/sample"
  output_path = "${path.module}/sample-function.zip"
}

resource "aws_lambda_function" "sample" {
  filename         = data.archive_file.sample.output_path
  function_name    = "${var.projectname}-sample"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.sample.output_base64sha256
  runtime          = "nodejs22.x"

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
    security_group_ids = [aws_security_group.ecs_alb.id]
  }

  environment {
    variables = {
      DB_HOST     = element(split(":", aws_db_instance.db.endpoint), 0)
      DB_PORT     = "5432"
      DB_NAME     = "postgres"
      DB_USER     = random_password.dbuser.result
      DB_PASSWORD = random_password.dbpass.result
    }
  }

  lifecycle {
    ignore_changes = [
      source_code_hash,
    ]
  }
}

data "archive_file" "bedrock-sample" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/bedrock"
  output_path = "${path.module}/bedrock-function.zip"
}

resource "aws_lambda_function" "bedrock-sample" {
  filename         = data.archive_file.bedrock-sample.output_path
  function_name    = "${var.projectname}-bedrock-sample"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "bedrock.lambda_handler"
  source_code_hash = data.archive_file.bedrock-sample.output_base64sha256
  runtime          = "python3.13"
  timeout = 60
  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
    security_group_ids = [aws_security_group.ecs_alb.id]
  }
}

data "archive_file" "ecs-task-sample" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/ecs-task"
  output_path = "${path.module}/ecs-task-function.zip"
}

resource "aws_lambda_function" "ecs-task-sample" {
  filename         = data.archive_file.ecs-task-sample.output_path
  function_name    = "${var.projectname}-ecs-task-sample"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.ecs-task-sample.output_base64sha256
  runtime          = "nodejs22.x"
  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
    security_group_ids = [aws_security_group.ecs_alb.id]
  }
}
