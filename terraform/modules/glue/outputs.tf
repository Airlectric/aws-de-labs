output "raw_database_name" {
  description = "Glue Data Catalog database for raw zone"
  value       = aws_glue_catalog_database.raw_data.name
}

output "processed_database_name" {
  description = "Glue Data Catalog database for processed zone"
  value       = aws_glue_catalog_database.processed_data.name
}

output "raw_crawler_name" {
  description = "Glue crawler that scans raw/ prefix"
  value       = aws_glue_crawler.raw_data.name
}
