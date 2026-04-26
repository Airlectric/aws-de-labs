variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from CDEM1"
  type        = string
}

variable "your_ip_cidr" {
  description = "Your public IP in CIDR notation (e.g. 203.0.113.45/32) — only this IP can connect to Redshift on port 5439"
  type        = string
}

variable "private_subnet_1a_id" {
  description = "Private subnet 1a ID from CDEM1"
  type        = string
}

variable "private_subnet_1b_id" {
  description = "Private subnet 1b ID from CDEM1"
  type        = string
}

variable "redshift_iam_role_arn" {
  description = "ARN of RedshiftIAMRole from CDEM1 — attached to cluster for S3 COPY access"
  type        = string
}

variable "redshift_master_password" {
  description = "Master password for the Redshift admin user (awsadmin)"
  type        = string
  sensitive   = true
}
