variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "Your AWS account ID (found top-right in AWS Console)"
  type        = string
}

variable "enable_nat_gateway" {
  description = "Create NAT Gateway ($0.32/hr). Set to false when tearing down to save costs. Re-enable when doing labs that need private subnet internet access."
  type        = bool
  default     = true
}
