# ============================================================
# IAM ROLE FOR FIREHOSE
# Firehose assumes this role to read from Kinesis and write to S3.
# Two separate policy statements — one per service boundary.
# ============================================================
resource "aws_iam_role" "firehose" {
  name        = "KinesisFirehoseS3Role"
  description = "Role assumed by Firehose to read Kinesis stream and write to S3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "firehose_access" {
  name = "FirehoseKinesisS3Access"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadFromKinesis"
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:ListShards"
        ]
        Resource = aws_kinesis_stream.user_events.arn
      },
      {
        Sid    = "WriteToS3"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          var.data_lake_bucket_arn,
          "${var.data_lake_bucket_arn}/*"
        ]
      }
    ]
  })
}

# ============================================================
# KINESIS DATA STREAM
# Real-time event highway. Accepts records from producers
# and makes them available to consumers within milliseconds.
# ============================================================
resource "aws_kinesis_stream" "user_events" {
  name             = "user-events-stream"
  shard_count      = 4
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Name        = "user-events-stream"
    Environment = "Production"
    Purpose     = "StreamingIngestion"
  }
}

# ============================================================
# KINESIS FIREHOSE DELIVERY STREAM
# Reads from the Kinesis stream and buffers records before
# landing them in S3. Buffer: flush every 60s OR every 64 MB,
# whichever comes first.
# ============================================================
resource "aws_kinesis_firehose_delivery_stream" "user_events_to_s3" {
  name        = "user-events-to-s3"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.user_events.arn
    role_arn           = aws_iam_role.firehose.arn
  }

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose.arn
    bucket_arn         = var.data_lake_bucket_arn
    prefix             = "raw/kinesis/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "raw/kinesis-errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/"

    buffering_size     = 64
    buffering_interval = 60

    compression_format = "UNCOMPRESSED"
  }

  tags = {
    Name        = "user-events-to-s3"
    Environment = "Production"
    Purpose     = "StreamToS3Delivery"
  }
}
