# ============================================================
# LAB 4.1 — PART 1: GLUE DATA CATALOG DATABASES
# ============================================================

# Step 1: Raw data database
resource "aws_glue_catalog_database" "raw_data" {
  name        = "raw_data"
  description = "Catalog for raw data ingested from source systems. Auto-discovered by crawlers."
}

# Step 2: Processed data database
resource "aws_glue_catalog_database" "processed_data" {
  name        = "processed_data"
  description = "Catalog for cleaned, validated data. Created from raw data transformations."
}

# ============================================================
# LAB 4.1 — PART 2: GLUE CRAWLER
# ============================================================

# Step 3: Crawler that scans raw/ and populates raw_data database
resource "aws_glue_crawler" "raw_data" {
  name          = "raw_data_crawler"
  role          = var.glue_service_role_arn
  database_name = aws_glue_catalog_database.raw_data.name
  description   = "Crawls raw/ prefix to auto-discover schema from CSV files"

  s3_target {
    path = "s3://${var.data_lake_bucket_id}/raw/"
  }

  schedule = "cron(0 2 * * ? *)"

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Name        = "raw_data_crawler"
    Environment = "Production"
  }
}

# ============================================================
# LAB 4.2 — GLUE ETL JOB
# ============================================================

# Step 1: Upload PySpark script to S3
# Glue pulls this at job start — source_hash re-uploads whenever
# the file content changes (acts like a checksum).
resource "aws_s3_object" "customer_etl_script" {
  bucket                 = var.data_lake_bucket_id
  key                    = "scripts/glue/customer_data_etl.py"
  source                 = "${path.module}/scripts/customer_data_etl.py"
  source_hash            = filemd5("${path.module}/scripts/customer_data_etl.py")
  content_type           = "text/x-python"
  server_side_encryption = "AES256"
}

# Step 2: Glue ETL job
resource "aws_glue_job" "customer_etl" {
  name         = "CustomerDataETL"
  role_arn     = var.glue_service_role_arn
  description  = "Reads messy customer CSVs from raw/, deduplicates, standardizes, writes Parquet to processed/"
  glue_version = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  command {
    name            = "glueetl"
    script_location = "s3://${var.data_lake_bucket_id}/scripts/glue/customer_data_etl.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-bookmark-option"              = "job-bookmark-disable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--TempDir"                          = "s3://${var.data_lake_bucket_id}/temp/glue/"
    "--BUCKET"                           = var.data_lake_bucket_id
  }

  depends_on = [aws_s3_object.customer_etl_script]

  tags = {
    Name        = "CustomerDataETL"
    Environment = "Production"
  }
}

# ============================================================
# LAB 4.3 — SCHEMA VALIDATION JOB
# ============================================================

# Upload schema validation script to S3
resource "aws_s3_object" "schema_validation_script" {
  bucket                 = var.data_lake_bucket_id
  key                    = "scripts/glue/customer_schema_validation.py"
  source                 = "${path.module}/scripts/customer_schema_validation.py"
  source_hash            = filemd5("${path.module}/scripts/customer_schema_validation.py")
  content_type           = "text/x-python"
  server_side_encryption = "AES256"
}

# Glue job that reads all 3 schema versions and proves they coexist
resource "aws_glue_job" "schema_validation" {
  name         = "CustomerSchemaValidation"
  role_arn     = var.glue_service_role_arn
  description  = "Reads customer data across schema versions v1.0-v3.0 to validate backwards compatibility"
  glue_version = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  command {
    name            = "glueetl"
    script_location = "s3://${var.data_lake_bucket_id}/scripts/glue/customer_schema_validation.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-bookmark-option"              = "job-bookmark-disable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--TempDir"                          = "s3://${var.data_lake_bucket_id}/temp/glue/"
    "--BUCKET"                           = var.data_lake_bucket_id
  }

  depends_on = [aws_s3_object.schema_validation_script]

  tags = {
    Name        = "CustomerSchemaValidation"
    Environment = "Production"
  }
}
