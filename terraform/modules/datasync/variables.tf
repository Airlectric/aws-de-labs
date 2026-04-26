variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "data_lake_bucket_id" {
  description = "data-lake-prod-ACCOUNT_ID bucket name (from s3 module)"
  type        = string
}

variable "data_lake_bucket_arn" {
  description = "data-lake-prod-ACCOUNT_ID bucket ARN (from s3 module)"
  type        = string
}

variable "private_subnet_1b_id" {
  description = "private-subnet-1b ID (from CDEM1 VPC module)"
  type        = string
}

variable "sg_private_compute_id" {
  description = "private-compute-sg ID (from CDEM1 VPC module)"
  type        = string
}
