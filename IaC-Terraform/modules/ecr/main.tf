

resource "aws_ecr_repository" "repositories" {

  for_each = toset(var.repositories)

  name = "${var.project_name}-${var.environment}-${each.value}"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${each.value}"
  }
}