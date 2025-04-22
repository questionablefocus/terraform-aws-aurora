variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "engine" {
  description = "Database engine type (aurora-mysql or aurora-postgresql)"
  type        = string
  validation {
    condition     = contains(["aurora-mysql", "aurora-postgresql"], var.engine)
    error_message = "Engine must be either aurora-mysql or aurora-postgresql"
  }
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the database will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where the database will be deployed"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the cluster"
  type        = list(string)
  default     = []
}

variable "is_public" {
  description = "Whether the database should be publicly accessible"
  type        = bool
  default     = false
}

variable "instances" {
  description = "List of instance configurations. When using provisioned instances, exactly one instance must be marked as primary (is_primary = true). Serverless instances can be mixed with provisioned instances."
  type = list(object({
    identifier     = string
    instance_class = optional(string)
    is_primary     = optional(bool)
    serverless = optional(object({
      min_capacity = number
      max_capacity = number
    }))
    auto_scaling = optional(object({
      min_capacity           = number
      max_capacity           = number
      target_cpu_utilization = number
    }))
  }))
  validation {
    condition = length([
      for instance in var.instances : instance
      if instance.serverless == null && instance.is_primary == true
      ]) == 1 || alltrue([
      for instance in var.instances : instance.serverless != null
    ])
    error_message = "When using provisioned instances, exactly one instance must be marked as primary (is_primary = true). For serverless-only clusters, is_primary should not be set."
  }
}

variable "parameter_group_name" {
  description = "Name of the DB parameter group to use"
  type        = string
  default     = null
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Preferred backup window in UTC"
  type        = string
  default     = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  description = "Preferred maintenance window in UTC"
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "log_retention_days" {
  description = "Number of days to retain database logs"
  type        = number
  default     = 30
}

variable "enable_iam_authentication" {
  description = "Whether to enable IAM authentication"
  type        = bool
  default     = false
}

variable "secrets_rotation_days" {
  description = "Number of days between automatic secrets rotation"
  type        = number
  default     = 30
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "database_admin"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
