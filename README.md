# AWS Aurora Module

This Terraform module creates an AWS Aurora database cluster with support for both MySQL and PostgreSQL engines. The module supports both provisioned and serverless v2 instances, with configurable autoscaling options.

## Features

- Support for both Aurora MySQL and PostgreSQL
- Mixed instance types (provisioned and serverless v2)
- Automatic password rotation using AWS Secrets Manager
- Configurable backup retention and maintenance windows
- IAM authentication support
- Custom parameter groups
- CloudWatch logging with configurable retention
- Support for both public and private subnets

## Usage

```hcl
module "aurora" {
  source  = "questionablefocus/aurora/aws"
  version = "1.1.0"

  name               = "my-database"
  engine             = "aurora-postgresql"
  engine_version     = "15.3"
  vpc_id             = "vpc-123456"
  subnet_ids         = ["subnet-123456", "subnet-789012"]
  is_public          = false
  security_group_ids = [aws_security_group.aurora_postgres.id]

  # Example with mixed provisioned and serverless instances
  instances = [
    {
      identifier     = "primary"
      instance_class = "db.r6g.large"
      is_primary     = true  # Required when using provisioned instances
    },
    {
      identifier     = "replica-1"
      instance_class = "db.r6g.large"
      auto_scaling   = {
        min_capacity = 1
        max_capacity = 4
        target_cpu_utilization = 70
      }
    },
    {
      identifier     = "serverless-1"
      instance_class = "db.serverless"
      serverless     = {
        min_capacity = 0.5
        max_capacity = 4
      }
    },
    {
      identifier     = "serverless-2"
      instance_class = "db.serverless"
      serverless     = {
        min_capacity = 0.5
        max_capacity = 4
      }
    }
  ]

  backup_retention_period   = 7
  log_retention_days        = 30
  enable_iam_authentication = true
  secrets_rotation_days     = 30

  tags = {
    Environment = "production"
  }
}
```

## Instance Configuration

The module supports three types of instance configurations:

1. **Provisioned Instances**

   - Must have exactly one instance marked as primary (`is_primary = true`)
   - Can include read replicas with optional autoscaling
   - Each instance must specify an `instance_class`

2. **Serverless Instances**

   - No primary instance required
   - All instances must specify `serverless` configuration
   - Each instance must specify `min_capacity` and `max_capacity`

3. **Mixed Instances**
   - Can combine provisioned and serverless instances
   - Must have exactly one provisioned instance marked as primary
   - Serverless instances can be added as additional read replicas

## Security Groups

The module does not create security groups, as these should be managed separately to allow for more flexible networking configurations. Below are example security group configurations for both PostgreSQL and MySQL:

### PostgreSQL Security Group Example

```hcl
resource "aws_security_group" "aurora_postgres" {
  name        = "aurora-postgres-sg"
  description = "Security group for Aurora PostgreSQL"
  vpc_id      = var.vpc_id

  # Allow inbound PostgreSQL traffic from specific CIDR blocks or security groups
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = ["10.0.0.0/16"]  # Example VPC CIDR
    # security_groups = [aws_security_group.application.id]  # Example application security group
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aurora-postgres-sg"
  }
}
```

### MySQL Security Group Example

```hcl
resource "aws_security_group" "aurora_mysql" {
  name        = "aurora-mysql-sg"
  description = "Security group for Aurora MySQL"
  vpc_id      = var.vpc_id

  # Allow inbound MySQL traffic from specific CIDR blocks or security groups
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks     = ["10.0.0.0/16"]  # Example VPC CIDR
    # security_groups = [aws_security_group.application.id]  # Example application security group
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aurora-mysql-sg"
  }
}
```

To use these security groups with the Aurora module, you would need to:

1. Create the security group(s) in your Terraform configuration
2. Pass the security group ID(s) to the Aurora module using the `security_group_ids` parameter:

```hcl
module "aurora" {
  # ... other configuration ...

  security_group_ids = [aws_security_group.aurora_postgres.id]  # or aurora_mysql.id for MySQL
}
```

## Authentication

### Password Authentication

When using password authentication, the master user password is automatically managed by Aurora and encrypted using a KMS key. To use the password in your application:

1. Retrieve the KMS key ID from the module output:
2. Use AWS Secrets Manager to retrieve the password with either `boto3` or `pydantic-settings`.

### IAM Authentication

To use IAM authentication:

1. Enable IAM authentication in the module:

   ```hcl
   enable_iam_authentication = true
   ```

2. Create an IAM policy for database access:

   ```hcl
   resource "aws_iam_policy" "db_access" {
     name = "db-access-policy"
     policy = jsonencode({
       Version = "2012-10-17"
       Statement = [
         {
           Effect = "Allow"
           Action = [
             "rds-db:connect"
           ]
           Resource = [
             "arn:aws:rds-db:region:account-id:dbuser:cluster-id/db-user"
           ]
         }
       ]
     })
   }
   ```

3. Connect to the database using IAM authentication:

   ```python
   import boto3
   import psycopg2

   def get_db_connection():
       rds_client = boto3.client('rds')
       token = rds_client.generate_db_auth_token(
           DBHostname=cluster_endpoint,
           Port=5432,
           DBUsername=db_user,
           Region='region'
       )

       conn = psycopg2.connect(
           host=cluster_endpoint,
           port=5432,
           database='postgres',
           user=db_user,
           password=token
       )
       return conn
   ```

## Managing Instances

### Adding Instances

To add new instances while maintaining backwards compatibility:

1. Add the new instance to the end of the `instances` list:

   ```hcl
   instances = [
     # ... existing instances ...
     {
       identifier = "new-instance"
       serverless = {
         min_capacity = 0.5
         max_capacity = 1
       }
     }
   ]
   ```

2. Apply the changes:
   ```bash
   terraform apply
   ```

The module will:

- Preserve existing instances
- Add the new instance
- Maintain the cluster's availability

### Removing Instances

To safely remove instances:

1. Remove the instance from the `instances` list
2. Apply the changes:
   ```bash
   terraform apply
   ```

The module will:

- Remove the instance from the cluster
- Maintain the cluster's availability
- Preserve data and connections

## Database Upgrades

### Minor Version Upgrades

To upgrade to a new minor version:

1. Update the `engine_version`:

   ```hcl
   engine_version = "16.7"  # Upgrade from 16.6 to 16.7
   ```

2. Apply the changes:
   ```bash
   terraform apply
   ```

Aurora will:

- Perform the upgrade during the maintenance window
- Maintain availability during the upgrade
- Automatically upgrade all instances

### Major Version Upgrades

For major version upgrades (e.g., PostgreSQL 15 to 16):

1. Create a new cluster with the target version
2. Use AWS Database Migration Service (DMS) to migrate data
3. Update application connections to the new cluster
4. Decommission the old cluster

This process ensures:

- Zero downtime migration
- Data consistency
- Rollback capability

## Notes

- The master password is automatically generated and stored in AWS Secrets Manager
- Applications should retrieve the password from Secrets Manager rather than using environment variables
- The module supports both provisioned and serverless v2 instances in the same cluster
- Autoscaling can be configured for both instance types and read replicas
- IAM authentication can be enabled alongside password authentication
- Custom parameter groups can be provided or a default one will be created
- CloudWatch logs are enabled for error, general, slowquery, and audit logs
