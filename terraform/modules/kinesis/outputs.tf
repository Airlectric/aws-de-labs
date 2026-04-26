output "kinesis_stream_arn" {
  description = "ARN of the Kinesis Data Stream"
  value       = aws_kinesis_stream.user_events.arn
}

output "kinesis_stream_name" {
  description = "Name of the Kinesis Data Stream"
  value       = aws_kinesis_stream.user_events.name
}

output "firehose_delivery_stream_arn" {
  description = "ARN of the Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.user_events_to_s3.arn
}

output "firehose_role_arn" {
  description = "ARN of the Firehose IAM role (needed by S3 bucket policy)"
  value       = aws_iam_role.firehose.arn
}
