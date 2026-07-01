output "backup_vault_name" {
  value = aws_backup_vault.main.name
}

output "backup_plan_id" {
  value = aws_backup_plan.main.id
}

output "backup_role_arn" {
  value = aws_iam_role.backup_role.arn
}