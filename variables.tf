variable "projectname" {
  type    = string
  default = "cfeg"
}

variable "networkcidr" {
  type    = string
  default = "192.168"
}

variable "awsregion" {
  type    = string
  default = "us-east-2"
}

variable "certarn" {
  type    = string
  default = ""
}

variable "hostedzoneid" {
  type    = string
  default = ""
}
