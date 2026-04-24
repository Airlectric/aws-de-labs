terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Local state for now. Once the S3 bucket is created in CDEM2,
  # run: terraform init -migrate-state  to move state to S3.
}

provider "aws" {
  region = var.aws_region
}

module "iam" {
  source         = "../modules/iam"
  aws_account_id = var.aws_account_id
}

module "vpc" {
  source             = "../modules/vpc"
  aws_region         = var.aws_region
  enable_nat_gateway = var.enable_nat_gateway
}
