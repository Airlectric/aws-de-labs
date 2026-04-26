variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "your_ip_cidr" {
  description = "Your public IP in CIDR notation (e.g. 203.0.113.45/32) — only this IP can connect to Redshift"
  type        = string
}

variable "redshift_master_password" {
  description = "Master password for Redshift awsadmin user (min 8 chars, upper+lower+number+symbol)"
  type        = string
  sensitive   = true
}
