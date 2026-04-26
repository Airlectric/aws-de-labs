output "redshift_cluster_id" {
  description = "Redshift cluster identifier"
  value       = module.redshift.redshift_cluster_id
}

output "redshift_endpoint" {
  description = "Redshift cluster endpoint for SQL connections"
  value       = module.redshift.redshift_endpoint
}

output "redshift_iam_role_arn" {
  description = "RedshiftS3Role ARN — use this in COPY commands"
  value       = module.redshift.redshift_iam_role_arn
}

output "redshift_secret_arn" {
  description = "Secrets Manager ARN for master credentials"
  value       = module.redshift.redshift_secret_arn
}
