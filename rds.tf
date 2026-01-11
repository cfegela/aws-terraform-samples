resource "random_password" "dbpass" {
  length  = 16
  lower   = true
  upper   = true
  special = false
}

resource "random_password" "dbuser" {
  length  = 16
  lower   = true
  upper   = true
  special = false
}

resource "aws_ssm_parameter" "dbpass" {
  name  = "${var.projectname}-db-password"
  type  = "SecureString"
  value = random_password.dbpass.result
}

resource "aws_ssm_parameter" "dbuser" {
  name  = "${var.projectname}-db-username"
  type  = "SecureString"
  value = random_password.dbuser.result
}

resource "aws_ssm_parameter" "dbhost" {
  name  = "${var.projectname}-db-host"
  type  = "SecureString"
  value = aws_db_instance.db.endpoint
}

resource "aws_db_subnet_group" "private" {
  name = "${var.projectname}-priv-subnet-group"
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id,
  ]
}

resource "aws_db_subnet_group" "public" {
  name = "${var.projectname}-pub-subnet-group"
  subnet_ids = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
    aws_subnet.public_c.id,
  ]
}

resource "aws_db_instance" "db" {
  identifier                  = "${var.projectname}-db-01"
  allocated_storage           = 100
  allow_major_version_upgrade = false
  apply_immediately           = true
  auto_minor_version_upgrade  = false
  backup_retention_period     = 7
  engine                      = "postgres"
  instance_class              = "db.t4g.large"
  multi_az                    = false
  max_allocated_storage       = 1000
  db_name                     = "auth"
  publicly_accessible         = false
  skip_final_snapshot         = true
  storage_encrypted           = true
  username                    = random_password.dbuser.result
  password                    = random_password.dbpass.result
  vpc_security_group_ids      = [aws_security_group.postgres.id]
  db_subnet_group_name        = aws_db_subnet_group.private.name
  deletion_protection         = true
  parameter_group_name        = aws_db_parameter_group.parameter_group.name
}

resource "aws_db_parameter_group" "parameter_group" {
  name   = "${var.projectname}-rds-pg"
  family = "postgres17"
  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }
}

resource "aws_security_group" "postgres" {
  vpc_id = aws_vpc.vpc.id
  name   = "${var.projectname}-db-sg"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
