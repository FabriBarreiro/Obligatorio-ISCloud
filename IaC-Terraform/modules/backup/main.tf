data "aws_caller_identity" "current" {}

locals {
  labrole_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
}

resource "aws_backup_vault" "main" {
  name = "${var.project_name}-${var.environment}-backup-vault"

  tags = {
    Name        = "${var.project_name}-${var.environment}-backup-vault"
    Component   = "backup"
    Environment = var.environment
  }
}

resource "aws_backup_plan" "main" {
  name = "${var.project_name}-${var.environment}-backup-plan"

  rule {
    rule_name         = "daily-ebs-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = var.backup_schedule

    lifecycle {
      delete_after = var.backup_retention_days
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-backup-plan"
    Component   = "backup"
    Environment = var.environment
  }
}

resource "aws_backup_selection" "tagged_ebs" {
  iam_role_arn = local.labrole_arn
  name         = "${var.project_name}-${var.environment}-tagged-ebs-selection"
  plan_id      = aws_backup_plan.main.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = var.resource_tag_key
    value = var.resource_tag_value
  }
}
