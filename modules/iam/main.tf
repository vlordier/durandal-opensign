variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "secrets_arns" {
  description = "Map of secret names to ARNs"
  type        = map(string)
}

variable "s3_bucket_arn" {
  type = string
}

# -----------------------------------------------------------------------------
# ECS Execution Role (pulls images, reads secrets)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_execution" {
  name = "${var.project_name}-${var.environment}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "${var.project_name}-${var.environment}-ecs-exec-secrets"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Resource = values(var.secrets_arns)
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
        ]
        Resource = ["*"]
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# ECS Task Role (app-level permissions: S3 access, etc.)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-${var.environment}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_s3" {
  name = "${var.project_name}-${var.environment}-ecs-task-s3"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion",
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_secrets" {
  name = "${var.project_name}-${var.environment}-ecs-task-secrets"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Resource = values(var.secrets_arns)
      }
    ]
  })
}

data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# S3 Access User (for OpenSign server S3 adapter which requires explicit keys)
# -----------------------------------------------------------------------------
resource "aws_iam_user" "s3_access" {
  name = "${var.project_name}-${var.environment}-s3-access"
  path = "/system/"
}

resource "aws_iam_user_policy" "s3_access" {
  name = "${var.project_name}-${var.environment}-s3-access"
  user = aws_iam_user.s3_access.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:PutObjectAcl",
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_access_key" "s3_access" {
  user = aws_iam_user.s3_access.name
}

output "s3_access_key_id" {
  value     = aws_iam_access_key.s3_access.id
  sensitive = true
}

output "s3_secret_access_key" {
  value     = aws_iam_access_key.s3_access.secret
  sensitive = true
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "ecs_execution_role_arn" {
  value = aws_iam_role.ecs_execution.arn
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task.arn
}
