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
  source_dir  = "${path.root}/lambda/sample"
  output_path = "${path.root}/sample-function.zip"
}

resource "aws_lambda_function" "sample" {
  filename         = data.archive_file.sample.output_path
  function_name    = "${var.projectname}-sample"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.sample.output_base64sha256
  runtime          = "nodejs22.x"

  vpc_config {
    subnet_ids         = [var.private_subnet_a_id, var.private_subnet_b_id, var.private_subnet_c_id]
    security_group_ids = [var.ecs_alb_sg_id]
  }

  environment {
    variables = {
      DB_HOST     = element(split(":", var.db_endpoint), 0)
      DB_PORT     = "5432"
      DB_NAME     = "postgres"
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password
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
  source_dir  = "${path.root}/lambda/bedrock"
  output_path = "${path.root}/bedrock-function.zip"
}

resource "aws_lambda_function" "bedrock-sample" {
  filename         = data.archive_file.bedrock-sample.output_path
  function_name    = "${var.projectname}-bedrock-sample"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "bedrock.lambda_handler"
  source_code_hash = data.archive_file.bedrock-sample.output_base64sha256
  runtime          = "python3.13"
  timeout          = 60
  vpc_config {
    subnet_ids         = [var.private_subnet_a_id, var.private_subnet_b_id, var.private_subnet_c_id]
    security_group_ids = [var.ecs_alb_sg_id]
  }
}

data "archive_file" "ecs-task-sample" {
  type        = "zip"
  source_dir  = "${path.root}/lambda/ecs-task"
  output_path = "${path.root}/ecs-task-function.zip"
}

resource "aws_lambda_function" "ecs-task-sample" {
  filename         = data.archive_file.ecs-task-sample.output_path
  function_name    = "${var.projectname}-ecs-task-sample"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.ecs-task-sample.output_base64sha256
  runtime          = "nodejs22.x"
  vpc_config {
    subnet_ids         = [var.private_subnet_a_id, var.private_subnet_b_id, var.private_subnet_c_id]
    security_group_ids = [var.ecs_alb_sg_id]
  }
}
