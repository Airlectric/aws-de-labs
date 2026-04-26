terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

# Pull IAM role ARNs from CDEM1 state so we don't hardcode them.
# terraform_remote_state reads another module's state file directly.
data "terraform_remote_state" "cdem1" {
  backend = "local"
  config = {
    path = "${path.module}/../cdem1/terraform.tfstate"
  }
}

# ── Lab 2.1: S3 Data Lake ────────────────────────────────────
module "s3" {
  source = "../modules/s3"

  aws_account_id         = var.aws_account_id
  aws_region             = var.aws_region
  data_engineer_role_arn = data.terraform_remote_state.cdem1.outputs.data_engineer_role_arn
  glue_service_role_arn  = data.terraform_remote_state.cdem1.outputs.glue_service_role_arn
  redshift_iam_role_arn  = data.terraform_remote_state.cdem1.outputs.redshift_iam_role_arn
}

# ── Lab 2.2: DataSync Batch Ingestion ────────────────────────
module "datasync" {
  source = "../modules/datasync"

  aws_account_id        = var.aws_account_id
  aws_region            = var.aws_region
  data_lake_bucket_id   = module.s3.data_lake_bucket_id
  data_lake_bucket_arn  = module.s3.data_lake_bucket_arn
  private_subnet_1b_id  = data.terraform_remote_state.cdem1.outputs.private_subnet_1b_id
  sg_private_compute_id = data.terraform_remote_state.cdem1.outputs.sg_private_compute_id

  depends_on = [module.s3]
}

# ── Lab 2.3: Kinesis Streaming Ingestion ─────────────────────
module "kinesis" {
  source = "../modules/kinesis"

  aws_account_id       = var.aws_account_id
  aws_region           = var.aws_region
  data_lake_bucket_arn = module.s3.data_lake_bucket_arn
  data_lake_bucket_id  = module.s3.data_lake_bucket_id

  depends_on = [module.s3]
}
