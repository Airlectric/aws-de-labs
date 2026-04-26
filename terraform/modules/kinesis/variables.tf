variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "data_lake_bucket_arn" {
  description = "ARN of the S3 data lake bucket (Firehose destination)"
  type        = string
}

variable "data_lake_bucket_id" {
  description = "ID (name) of the S3 data lake bucket"
  type        = string
}
