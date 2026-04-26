# ── Lab 2.1: S3 ──────────────────────────────────────────────
output "data_lake_bucket_id" {
  description = "data-lake-prod-ACCOUNT_ID bucket name"
  value       = module.s3.data_lake_bucket_id
}

output "data_lake_bucket_arn" {
  description = "data-lake-prod-ACCOUNT_ID bucket ARN"
  value       = module.s3.data_lake_bucket_arn
}

output "logs_bucket_id" {
  description = "data-lake-prod-logs-ACCOUNT_ID bucket name"
  value       = module.s3.logs_bucket_id
}

output "cloudtrail_arn" {
  description = "data-lake-audit-trail ARN"
  value       = module.s3.cloudtrail_arn
}

# ── Lab 2.2: DataSync ────────────────────────────────────────
output "datasync_server_id" {
  description = "datasync-test-server EC2 instance ID"
  value       = module.datasync.datasync_server_id
}

output "datasync_task_arn" {
  description = "raw-to-processed-sync DataSync task ARN"
  value       = module.datasync.datasync_task_arn
}

output "datasync_sns_topic_arn" {
  description = "datasync-notifications SNS topic ARN"
  value       = module.datasync.datasync_sns_topic_arn
}

# ── Lab 2.3: Kinesis ─────────────────────────────────────────
output "kinesis_stream_arn" {
  description = "user-events-stream Kinesis Data Stream ARN"
  value       = module.kinesis.kinesis_stream_arn
}

output "firehose_delivery_stream_arn" {
  description = "user-events-to-s3 Firehose delivery stream ARN"
  value       = module.kinesis.firehose_delivery_stream_arn
}
