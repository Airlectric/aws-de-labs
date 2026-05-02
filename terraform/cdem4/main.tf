terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
}

# ── Remote state: CDEM1 (IAM role ARNs) ──────────────────────
data "terraform_remote_state" "cdem1" {
  backend = "local"
  config = {
    path = "${path.module}/../cdem1/terraform.tfstate"
  }
}

# ── Remote state: CDEM2 (S3 bucket ID and ARN) ───────────────
data "terraform_remote_state" "cdem2" {
  backend = "local"
  config = {
    path = "${path.module}/../cdem2/terraform.tfstate"
  }
}

# ── Lab 4.1 / 4.2 / 4.3 — Glue ──────────────────────────────
module "glue" {
  source = "../modules/glue"

  aws_account_id        = var.aws_account_id
  aws_region            = var.aws_region
  data_lake_bucket_id   = data.terraform_remote_state.cdem2.outputs.data_lake_bucket_id
  data_lake_bucket_arn  = data.terraform_remote_state.cdem2.outputs.data_lake_bucket_arn
  glue_service_role_arn = data.terraform_remote_state.cdem1.outputs.glue_service_role_arn
}
