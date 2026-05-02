variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "data_lake_bucket_id" {
  description = "data-lake-prod-ACCOUNT_ID bucket name (from CDEM2)"
  type        = string
}

variable "data_lake_bucket_arn" {
  description = "data-lake-prod-ACCOUNT_ID bucket ARN (from CDEM2)"
  type        = string
}

variable "glue_service_role_arn" {
  description = "GlueServiceRole ARN (from CDEM1)"
  type        = string
}
