output "datasync_server_id" {
  description = "datasync-test-server EC2 instance ID"
  value       = aws_instance.datasync_server.id
}

output "datasync_task_arn" {
  description = "raw-to-processed-sync DataSync task ARN"
  value       = aws_datasync_task.raw_to_processed.arn
}

output "datasync_s3_role_arn" {
  description = "DataSyncS3Role ARN"
  value       = aws_iam_role.datasync_s3.arn
}

output "datasync_sns_topic_arn" {
  description = "datasync-notifications SNS topic ARN"
  value       = aws_sns_topic.datasync_notifications.arn
}
