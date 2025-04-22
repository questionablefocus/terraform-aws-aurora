resource "aws_cloudwatch_log_group" "main" {
  for_each = toset([
    "error",
    "general",
    "slowquery",
    "audit"
  ])

  name              = "/aws/rds/cluster/${var.name}/${each.key}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}
