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
