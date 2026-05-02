# ============================================================
# EC2 INSTANCE — simulated on-premises server
# Private subnet, no public IP. In a real on-premises setup
# this would be a physical server connected via VPN or
# Direct Connect. Here we simulate it with EC2.
# ============================================================
resource "aws_instance" "datasync_server" {
  ami                         = "ami-02b9a589195146a8f"
  instance_type               = "t2.micro"
  subnet_id                   = var.private_subnet_1b_id
  vpc_security_group_ids      = [var.sg_private_compute_id]
  associate_public_ip_address = false

  tags = {
    Name        = "datasync-test-server"
    Environment = "Lab"
    Purpose     = "SimulatedOnPremServer"
  }
}

# ============================================================
# IAM ROLE FOR DATASYNC
# DataSync assumes this role when reading/writing S3.
# Trust: datasync.amazonaws.com
# Policy: scoped to the data lake bucket only.
# ============================================================
resource "aws_iam_role" "datasync_s3" {
  name        = "DataSyncS3Role"
  description = "Role assumed by DataSync to read/write the data lake S3 bucket"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "datasync.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "datasync_s3_access" {
  name = "DataSyncS3Access"
  role = aws_iam_role.datasync_s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetObjectTagging",
        "s3:PutObjectTagging"
      ]
      Resource = [
        var.data_lake_bucket_arn,
        "${var.data_lake_bucket_arn}/*"
      ]
    }]
  })
}

# ============================================================
# DATASYNC S3 LOCATIONS
# source      → raw/       (simulates the on-premises share)
# destination → processed/ (the cloud landing zone)
#
# Both point to the same bucket but different key prefixes.
# ============================================================
resource "aws_datasync_location_s3" "raw" {
  s3_bucket_arn = var.data_lake_bucket_arn
  subdirectory  = "/raw"

  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_s3.arn
  }

  tags = { Name = "onprem-s3-raw-location" }
}

resource "aws_datasync_location_s3" "processed" {
  s3_bucket_arn = var.data_lake_bucket_arn
  subdirectory  = "/processed"

  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_s3.arn
  }

  tags = { Name = "aws-s3-processed-location" }
}

# ============================================================
# CLOUDWATCH LOG GROUP FOR DATASYNC
# DataSync requires a log group ARN when log_level != OFF.
# The log group resource policy grants DataSync permission
# to create log streams and write events into this group.
# ============================================================
resource "aws_cloudwatch_log_group" "datasync" {
  name              = "/aws/datasync"
  retention_in_days = 14
  tags              = { Name = "datasync-logs" }
}

resource "aws_cloudwatch_log_resource_policy" "datasync" {
  policy_name = "datasync-cloudwatch-policy"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowDataSyncLogs"
      Effect    = "Allow"
      Principal = { Service = "datasync.amazonaws.com" }
      Action    = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource  = "${aws_cloudwatch_log_group.datasync.arn}:*"
    }]
  })
}

# ============================================================
# DATASYNC TASK
# transfer_mode = CHANGED  — only new/modified files (incremental)
# verify_mode   = ONLY_FILES_TRANSFERRED — checksum every file copied
# schedule      = daily 03:00 UTC (off-peak)
# ============================================================
resource "aws_datasync_task" "raw_to_processed" {
  name                     = "raw-to-processed-sync"
  source_location_arn      = aws_datasync_location_s3.raw.arn
  destination_location_arn = aws_datasync_location_s3.processed.arn
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.datasync.arn

  options {
    transfer_mode          = "CHANGED"
    verify_mode            = "ONLY_FILES_TRANSFERRED"
    preserve_deleted_files = "PRESERVE"
    log_level              = "BASIC"
    posix_permissions      = "NONE"
    uid                    = "NONE"
    gid                    = "NONE"
  }

  schedule {
    schedule_expression = "cron(0 3 * * ? *)"
  }

  tags = {
    Name        = "raw-to-processed-sync"
    Environment = "Production"
  }
}

# ============================================================
# SNS TOPIC — failure notifications
# Subscribe your email via:
#   aws sns subscribe --topic-arn <arn> --protocol email --notification-endpoint <email>
# ============================================================
resource "aws_sns_topic" "datasync_notifications" {
  name = "datasync-notifications"
  tags = { Name = "datasync-notifications" }
}

# ============================================================
# CLOUDWATCH ALARM
# Fires if any DataSync execution fails within a 1-hour window.
# ============================================================
resource "aws_cloudwatch_metric_alarm" "datasync_failures" {
  alarm_name          = "datasync-task-failures"
  alarm_description   = "Alert if any DataSync task execution fails"
  namespace           = "AWS/DataSync"
  metric_name         = "TaskExecutionsFailed"
  statistic           = "Sum"
  period              = 3600
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.datasync_notifications.arn]

  tags = { Name = "datasync-task-failures" }
}
