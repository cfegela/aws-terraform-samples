resource "aws_instance" "ec2" {
  ami                  = "ami-0b016c703b95ecbe4"
  instance_type        = "t3.micro"
  subnet_id            = aws_subnet.private_a.id
  iam_instance_profile = aws_iam_instance_profile.ec2-profile.id
  root_block_device {
    delete_on_termination = true
    volume_size           = "100"
    volume_type           = "gp2"
  }
  tags = {
    Name = "${var.projectname}-util-1"
  }
}

resource "aws_iam_role" "ec2-role" {
  name = "${var.projectname}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "ec2-profile" {
  name = "${var.projectname}-ec2-profile"
  role = aws_iam_role.ec2-role.name
}

resource "aws_iam_policy" "ec2-iam-policy" {
  name = "ec2-iam-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:*",
          "sqs:*"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2-iam-policy-attach" {
  role       = aws_iam_role.ec2-role.name
  policy_arn = aws_iam_policy.ec2-iam-policy.arn
}

resource "aws_iam_role_policy_attachment" "ssm-managed-instance-attach" {
  role       = aws_iam_role.ec2-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
