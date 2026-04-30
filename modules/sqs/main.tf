resource "aws_sqs_queue" "sqs-queue" {
  name                        = "${var.projectname}-sqs-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
}

resource "aws_ssm_parameter" "sqs-queue-url" {
  name  = "${var.projectname}-sqs-queue-url"
  type  = "SecureString"
  value = aws_sqs_queue.sqs-queue.id
}
