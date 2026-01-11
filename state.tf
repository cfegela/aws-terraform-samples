terraform {
  backend "s3" {
    bucket       = "edgar-tf-state"
    key          = "terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
