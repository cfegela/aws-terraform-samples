terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.awsregion
}

module "vpc" {
  source      = "./modules/vpc"
  projectname = var.projectname
  networkcidr = var.networkcidr
  awsregion   = var.awsregion
}

module "ecr" {
  source      = "./modules/ecr"
  projectname = var.projectname
}

module "s3" {
  source      = "./modules/s3"
  projectname = var.projectname
}

module "sqs" {
  source      = "./modules/sqs"
  projectname = var.projectname
}

module "iam" {
  source      = "./modules/iam"
  projectname = var.projectname
}

module "ec2" {
  source              = "./modules/ec2"
  projectname         = var.projectname
  private_subnet_a_id = module.vpc.private_subnet_a_id
}

module "rds" {
  source              = "./modules/rds"
  projectname         = var.projectname
  vpc_id              = module.vpc.vpc_id
  private_subnet_a_id = module.vpc.private_subnet_a_id
  private_subnet_b_id = module.vpc.private_subnet_b_id
  private_subnet_c_id = module.vpc.private_subnet_c_id
  public_subnet_a_id  = module.vpc.public_subnet_a_id
  public_subnet_b_id  = module.vpc.public_subnet_b_id
  public_subnet_c_id  = module.vpc.public_subnet_c_id
}

module "ecs" {
  source              = "./modules/ecs"
  projectname         = var.projectname
  awsregion           = var.awsregion
  certarn             = var.certarn
  hostedzoneid        = var.hostedzoneid
  vpc_id              = module.vpc.vpc_id
  public_subnet_a_id  = module.vpc.public_subnet_a_id
  public_subnet_b_id  = module.vpc.public_subnet_b_id
  public_subnet_c_id  = module.vpc.public_subnet_c_id
  private_subnet_a_id = module.vpc.private_subnet_a_id
  private_subnet_b_id = module.vpc.private_subnet_b_id
  private_subnet_c_id = module.vpc.private_subnet_c_id
}

module "lambda" {
  source              = "./modules/lambda"
  projectname         = var.projectname
  private_subnet_a_id = module.vpc.private_subnet_a_id
  private_subnet_b_id = module.vpc.private_subnet_b_id
  private_subnet_c_id = module.vpc.private_subnet_c_id
  ecs_alb_sg_id       = module.ecs.ecs_alb_sg_id
  db_endpoint         = module.rds.db_endpoint
  db_username         = module.rds.db_username
  db_password         = module.rds.db_password
}

module "api_gateway" {
  source                       = "./modules/api-gateway"
  projectname                  = var.projectname
  certarn                      = var.certarn
  hostedzoneid                 = var.hostedzoneid
  sample_invoke_arn            = module.lambda.sample_invoke_arn
  sample_function_name         = module.lambda.sample_function_name
  bedrock_sample_invoke_arn    = module.lambda.bedrock_sample_invoke_arn
  bedrock_sample_function_name = module.lambda.bedrock_sample_function_name
  ecs_task_sample_invoke_arn   = module.lambda.ecs_task_sample_invoke_arn
}
