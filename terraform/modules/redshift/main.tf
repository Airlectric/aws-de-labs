# ============================================================
# S3 VPC ENDPOINT
# A Gateway endpoint routes Redshift→S3 traffic entirely
# within the AWS backbone — it never hits the internet.
# Benefits: faster COPY commands, no bandwidth charges,
# and data never leaves the VPC (compliance requirement).
# ============================================================
# Reference the existing S3 Gateway endpoint in this VPC.
# (One already exists from prior lab work — Gateway endpoints are
# VPC-scoped so only one per service per VPC is allowed.)
data "aws_vpc_endpoint" "s3" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  state        = "available"
}

# ============================================================
# SECURITY GROUP
# Port 5439 is Redshift's SQL port. Inbound restricted to
# your IP address only — not the full VPC, not the internet.
# This means only YOU can run SQL queries against this cluster.
# ============================================================
resource "aws_security_group" "redshift" {
  name        = "redshift-security-group"
  description = "Security group for Redshift cluster - allows inbound on port 5439 from specific IP"
  vpc_id      = var.vpc_id

  ingress {
    description = "Redshift SQL from your IP only"
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  egress {
    description = "Allow all outbound (Redshift needs to reach S3, CloudWatch, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "redshift-security-group"
    Environment = "Learning"
    Tier        = "3"
    Lab         = "3.1"
  }
}

# ============================================================
# SECRETS MANAGER — REDSHIFT MASTER PASSWORD
# Stores the admin password as a managed secret so it never
# appears in Terraform state, code, or logs in plain text.
# Redshift reads it directly from Secrets Manager at cluster
# creation time.
# ============================================================
resource "aws_secretsmanager_secret" "redshift_password" {
  name                    = "redshift/master-password"
  description             = "Redshift cluster master user password"
  recovery_window_in_days = 7

  tags = {
    Name        = "redshift-master-password"
    Environment = "Learning"
    Tier        = "3"
    Lab         = "3.1"
  }
}

resource "aws_secretsmanager_secret_version" "redshift_password" {
  secret_id = aws_secretsmanager_secret.redshift_password.id
  secret_string = jsonencode({
    username = "awsadmin"
    password = var.redshift_master_password
  })
}

# ============================================================
# REDSHIFT SUBNET GROUP
# Tells Redshift which VPC subnets it is allowed to deploy
# nodes into. We use both private subnets (1a and 1b) so
# Redshift can spread nodes across two Availability Zones
# for high availability.
# ============================================================
resource "aws_redshift_subnet_group" "main" {
  name        = "redshift-tier3-subnet-group"
  description = "Subnet group for Tier 3 Redshift labs"
  subnet_ids  = [var.private_subnet_1a_id, var.private_subnet_1b_id]

  tags = {
    Name        = "redshift-tier3-subnet-group"
    Environment = "Learning"
    Tier        = "3"
    Lab         = "3.1"
  }
}

# ============================================================
# REDSHIFT CLUSTER
# 2 x dc2.large nodes = 160 GB SSD storage per node.
# Deployed in the private subnet group, not publicly
# accessible. Uses the RedshiftIAMRole from Lab 1.1 for
# S3 COPY access — no credentials embedded anywhere.
# ============================================================
resource "aws_redshift_cluster" "main" {
  cluster_identifier        = "redshift-tier3-lab"
  database_name             = "analytics"
  master_username           = "awsadmin"
  master_password           = var.redshift_master_password
  node_type                 = "ra3.large"
  cluster_type              = "multi-node"
  number_of_nodes           = 2

  cluster_subnet_group_name = aws_redshift_subnet_group.main.name
  vpc_security_group_ids    = [aws_security_group.redshift.id]
  iam_roles                 = [var.redshift_iam_role_arn]

  publicly_accessible                  = false
  encrypted                            = true
  automated_snapshot_retention_period  = 2
  skip_final_snapshot                  = false
  final_snapshot_identifier            = "redshift-tier3-lab-final-snapshot"

  tags = {
    Name        = "redshift-tier3-lab"
    Environment = "Learning"
    Tier        = "3"
    Lab         = "3.1"
  }

  depends_on = [aws_secretsmanager_secret_version.redshift_password]
}

# ============================================================
# REDSHIFT LOGGING
# Separated into its own resource (logging block in
# aws_redshift_cluster is deprecated as of provider v5).
# - useractivitylog: every SQL query run (what ran)
# - userlog:         user creation/deletion (who exists)
# - connectionlog:   connect/disconnect events (who connected when)
# - systemlog:       cluster health and system events
# ============================================================
resource "aws_redshift_logging" "main" {
  cluster_identifier   = aws_redshift_cluster.main.cluster_identifier
  log_destination_type = "cloudwatch"
  log_exports          = ["useractivitylog", "userlog", "connectionlog"]
}
