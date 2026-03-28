variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

resource "aws_ecr_repository" "server" {
  name                 = "${var.project_name}/server"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "${var.project_name}-${var.environment}-server-ecr" }
}

resource "aws_ecr_repository" "client" {
  name                 = "${var.project_name}/client"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "${var.project_name}-${var.environment}-client-ecr" }
}

resource "aws_ecr_lifecycle_policy" "server" {
  repository = aws_ecr_repository.server.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "client" {
  repository = aws_ecr_repository.client.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

output "server_repository_url" {
  value = aws_ecr_repository.server.repository_url
}

output "client_repository_url" {
  value = aws_ecr_repository.client.repository_url
}
