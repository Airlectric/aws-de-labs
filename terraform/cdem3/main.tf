terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

# Pull VPC outputs from CDEM1 state
data "terraform_remote_state" "cdem1" {
  backend = "local"
  config = {
    path = "${path.module}/../cdem1/terraform.tfstate"
  }
}

# ── Glue Data Catalog Database ───────────────────────────────
# Redshift Spectrum registers external table definitions here.
# The 'default' database must exist before CREATE EXTERNAL SCHEMA
# or CREATE EXTERNAL TABLE can run successfully.
resource "aws_glue_catalog_database" "default" {
  name        = "default"
  description = "Default Glue Data Catalog database for Redshift Spectrum external tables"
}

# ── Lab 3.1: Redshift Cluster Setup + Security ───────────────
module "redshift" {
  source = "../modules/redshift"

  aws_account_id        = var.aws_account_id
  aws_region            = var.aws_region
  vpc_id                = data.terraform_remote_state.cdem1.outputs.vpc_id
  your_ip_cidr          = var.your_ip_cidr
  private_subnet_1a_id  = data.terraform_remote_state.cdem1.outputs.private_subnet_1a_id
  private_subnet_1b_id  = data.terraform_remote_state.cdem1.outputs.private_subnet_1b_id
  redshift_iam_role_arn = data.terraform_remote_state.cdem1.outputs.redshift_iam_role_arn
  redshift_master_password = var.redshift_master_password
}
