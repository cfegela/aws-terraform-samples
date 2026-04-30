output "db_endpoint" {
  value = aws_db_instance.db.endpoint
}

output "db_username" {
  value     = random_password.dbuser.result
  sensitive = true
}

output "db_password" {
  value     = random_password.dbpass.result
  sensitive = true
}
