output "redshift_cluster_id" {
  description = "Redshift cluster identifier"
  value       = aws_redshift_cluster.main.cluster_identifier
}

output "redshift_endpoint" {
  description = "Redshift cluster endpoint for SQL connections"
  value       = aws_redshift_cluster.main.endpoint
}

output "redshift_iam_role_arn" {
  description = "RedshiftIAMRole ARN attached to cluster — use this in COPY commands"
  value       = var.redshift_iam_role_arn
}

output "redshift_secret_arn" {
  description = "Secrets Manager ARN for master credentials"
  value       = aws_secretsmanager_secret.redshift_password.arn
}
