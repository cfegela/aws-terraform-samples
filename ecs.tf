resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.projectname}-ecs-cluster"
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name = "${var.projectname}-ecs-cluster-logs"
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "nginx"
  execution_role_arn       = aws_iam_role.ecs_iam_role.arn
  task_role_arn            = aws_iam_role.ecs_iam_role.arn
  container_definitions    = <<EOF
  [
    {
      "name": "nginx",
      "image": "nginx",
      "portMappings": [
        {
          "containerPort": 80
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-create-group": "true",
          "awslogs-region": "${var.awsregion}",
          "awslogs-group": "${var.projectname}-ecs-cluster-logs",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  EOF
  cpu                      = 512
  memory                   = 1024
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
}

resource "aws_ecs_service" "ecs_service" {
  name                   = var.projectname
  desired_count          = 1
  cluster                = aws_ecs_cluster.ecs_cluster.id
  task_definition        = aws_ecs_task_definition.ecs_task_definition.arn
  launch_type            = "FARGATE"
  enable_execute_command = true
  network_configuration {
    assign_public_ip = false
    security_groups = [
      aws_security_group.ecs_alb.id,
    ]
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
      aws_subnet.private_c.id,
    ]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
    container_name   = "nginx"
    container_port   = "80"
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_lb_target_group" "ecs_target_group" {
  name        = "${var.projectname}-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc.id
  health_check {
    enabled  = true
    path     = "/"
    protocol = "HTTP"
  }
}

resource "aws_alb" "ecs_alb" {
  name               = "${var.projectname}-ecs-alb"
  internal           = false
  load_balancer_type = "application"
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
    aws_subnet.public_c.id,
  ]
  security_groups = [
    aws_security_group.ecs_alb.id
  ]
}

resource "aws_alb_listener" "https_listener" {
  load_balancer_arn = aws_alb.ecs_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certarn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
  }
}

resource "aws_alb_listener" "http_listener" {
  load_balancer_arn = aws_alb.ecs_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_security_group" "ecs_alb" {
  name   = "${var.projectname}-ecs-alb"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ecs_iam_role" {
  name               = "${var.projectname}-ecs-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_iam_assume_role.json
}

data "aws_iam_policy_document" "ecs_iam_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "ecs_iam_execution_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_iam_attachment" {
  role       = aws_iam_role.ecs_iam_role.name
  policy_arn = data.aws_iam_policy.ecs_iam_execution_role.arn
}

resource "aws_iam_role_policy" "ecs_iam_role_permissions" {
  name = "${var.projectname}-ecs-policy"
  role = aws_iam_role.ecs_iam_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssmmessages:*",
          "ssm:*",
          "secretsmanager:*",
          "kms:*",
          "sqs:*",
          "logs:*",
          "s3:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_route53_record" "alb-pub-dns-name" {
  zone_id = var.hostedzoneid
  name    = "ecs.edgar.oddball.io"
  type    = "CNAME"
  ttl     = 300
  records = [aws_alb.ecs_alb.dns_name]
}

resource "aws_ecs_task_definition" "sample-task" {
  family                   = "sample-task"
  execution_role_arn       = aws_iam_role.ecs_iam_role.arn
  task_role_arn            = aws_iam_role.ecs_iam_role.arn
  container_definitions    = <<EOF
  [
    {
      "name": "sample-task",
      "image": "609543642808.dkr.ecr.us-east-2.amazonaws.com/edgar-sample-task:latest",
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-create-group": "true",
          "awslogs-region": "${var.awsregion}",
          "awslogs-group": "${var.projectname}-ecs-cluster-logs",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  EOF
  cpu                      = 512
  memory                   = 1024
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
}
