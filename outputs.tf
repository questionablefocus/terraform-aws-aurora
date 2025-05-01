output "cluster_id" {
  description = "The ID of the Aurora cluster"
  value       = aws_rds_cluster.main.id
}

output "cluster_endpoint" {
  description = "The cluster endpoint"
  value       = aws_rds_cluster.main.endpoint
}

output "cluster_port" {
  description = "The port on which the cluster accepts connections"
  value       = aws_rds_cluster.main.port
}

output "cluster_reader_endpoint" {
  description = "The reader endpoint for the cluster"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "master_username" {
  description = "The master username for the database"
  value       = var.master_username
}

output "master_user_secret_kms_key_id" {
  description = "The KMS key ID used to encrypt the master user password"
  value       = aws_rds_cluster.main.master_user_secret[0].kms_key_id
}

output "master_user_secret_secret_arn" {
  description = "The ARN of the secret containing the master user password"
  value       = aws_rds_cluster.main.master_user_secret[0].secret_arn
}

output "cluster_arn" {
  description = "The ARN of the Aurora cluster"
  value       = aws_rds_cluster.main.arn
}

output "instance_endpoints" {
  description = "Map of instance identifiers to their endpoints"
  value = {
    for instance in aws_rds_cluster_instance.main : instance.identifier => instance.endpoint
  }
}

output "parameter_group_id" {
  description = "The ID of the parameter group"
  value       = try(aws_rds_cluster_parameter_group.main[0].id, var.parameter_group_name)
}
