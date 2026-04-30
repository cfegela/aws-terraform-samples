resource "aws_s3_bucket" "file-ingest" {
  bucket = "${var.projectname}-file-ingest"
}
