resource "aws_ecr_repository" "api" {
  name         = "${var.projectname}-api"
  force_delete = true
}

resource "aws_ecr_repository" "sample-task" {
  name         = "${var.projectname}-sample-task"
}
