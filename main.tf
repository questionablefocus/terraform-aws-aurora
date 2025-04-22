locals {
  provisioned_instances   = [for instance in var.instances : instance if instance.serverless == null]
  serverless_instances    = [for instance in var.instances : instance if instance.serverless != null]
  has_serverless          = length(local.serverless_instances) > 0
  min_serverless_capacity = local.has_serverless ? min([for instance in local.serverless_instances : instance.serverless.min_capacity]...) : null
  max_serverless_capacity = local.has_serverless ? max([for instance in local.serverless_instances : instance.serverless.max_capacity]...) : null
  is_postgres             = var.engine == "aurora-postgresql"
  engine_major_version    = split(".", var.engine_version)[0]
}

resource "aws_rds_cluster" "main" {
  cluster_identifier                  = var.name
  engine                              = var.engine
  engine_mode                         = local.has_serverless ? "provisioned" : null
  engine_version                      = var.engine_version
  database_name                       = local.is_postgres ? "postgres" : null
  master_username                     = var.master_username
  manage_master_user_password         = true
  master_user_secret_kms_key_id       = aws_kms_key.main.key_id
  vpc_security_group_ids              = var.security_group_ids
  db_subnet_group_name                = aws_db_subnet_group.main.name
  skip_final_snapshot                 = true
  backup_retention_period             = var.backup_retention_period
  preferred_backup_window             = var.preferred_backup_window
  preferred_maintenance_window        = var.preferred_maintenance_window
  db_cluster_parameter_group_name     = var.parameter_group_name
  enable_http_endpoint                = local.is_postgres ? true : null
  iam_database_authentication_enabled = var.enable_iam_authentication
  storage_encrypted                   = true
  copy_tags_to_snapshot               = true
  tags                                = var.tags

  dynamic "serverlessv2_scaling_configuration" {
    for_each = local.has_serverless ? [1] : []
    content {
      min_capacity = local.min_serverless_capacity
      max_capacity = local.max_serverless_capacity
    }
  }
}

resource "aws_kms_key" "main" {
  description = "KMS Key for Aurora"
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_rds_cluster_instance" "main" {
  for_each = { for idx, instance in var.instances : instance.identifier => instance }

  identifier          = each.value.identifier
  cluster_identifier  = aws_rds_cluster.main.id
  instance_class      = each.value.instance_class
  engine              = var.engine
  engine_version      = var.engine_version
  publicly_accessible = var.is_public
  tags                = var.tags
}

resource "aws_rds_cluster_parameter_group" "main" {
  count = var.parameter_group_name == null ? 1 : 0

  name        = "${var.name}-parameter-group"
  family      = "${var.engine}${local.engine_major_version}"
  description = "Custom parameter group for ${var.name}"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = var.tags
}
