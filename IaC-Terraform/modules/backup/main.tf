resource "aws_backup_vault" "main" {
  name = "${var.project_name}-${var.environment}-backup-vault"

  tags = {
    Name        = "${var.project_name}-${var.environment}-backup-vault"
    Component   = "backup"
    Environment = var.environment
  }
}

resource "aws_iam_role" "backup_role" {
  name = "${var.project_name}-${var.environment}-aws-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-aws-backup-role"
    Component   = "backup"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
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
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "${var.project_name}-${var.environment}-tagged-ebs-selection"
  plan_id      = aws_backup_plan.main.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = var.resource_tag_key
    value = var.resource_tag_value
  }
}