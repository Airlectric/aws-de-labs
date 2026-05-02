output "raw_database_name" {
  description = "Glue Data Catalog database for raw zone"
  value       = module.glue.raw_database_name
}

output "processed_database_name" {
  description = "Glue Data Catalog database for processed zone"
  value       = module.glue.processed_database_name
}

output "raw_crawler_name" {
  description = "raw_data_crawler name"
  value       = module.glue.raw_crawler_name
}
