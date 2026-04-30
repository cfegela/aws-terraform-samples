variable "projectname" {
  type = string
}

variable "private_subnet_a_id" {
  type = string
}

variable "private_subnet_b_id" {
  type = string
}

variable "private_subnet_c_id" {
  type = string
}

variable "ecs_alb_sg_id" {
  type = string
}

variable "db_endpoint" {
  type = string
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}
