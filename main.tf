locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
    },
    var.additional_tags,
  )
}

# -----------------------------------------------------------------------------
# DocumentDB password (from variable)
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Shared ECS Tasks Security Group (created here to break circular dependency)
# -----------------------------------------------------------------------------
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-"
  description = "ECS tasks security group"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-ecs-sg" }

  lifecycle { create_before_destroy = true }
}

# -----------------------------------------------------------------------------
# VPC & Networking
# -----------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# -----------------------------------------------------------------------------
# ECR Repositories
# -----------------------------------------------------------------------------
module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

# -----------------------------------------------------------------------------
# S3 Bucket for Documents
# -----------------------------------------------------------------------------
module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
}

# -----------------------------------------------------------------------------
# Secrets Manager
# -----------------------------------------------------------------------------
module "secrets" {
  source = "./modules/secrets"

  project_name         = var.project_name
  environment          = var.environment
  app_id               = var.app_id
  master_key           = var.master_key
  app_name             = var.app_name
  docdb_username       = var.docdb_master_username
  docdb_password       = var.docdb_password
  docdb_endpoint       = module.mongodb.private_ip
  docdb_port           = 27017
  smtp_enable          = var.smtp_enable
  smtp_host            = var.smtp_host
  smtp_port            = var.smtp_port
  smtp_user_email      = var.smtp_user_email
  smtp_pass            = var.smtp_pass
  mailgun_api_key      = var.mailgun_api_key
  mailgun_domain       = var.mailgun_domain
  mailgun_sender       = var.mailgun_sender
  s3_bucket            = module.s3.bucket_name
  s3_bucket_arn        = module.s3.bucket_arn
  aws_region           = var.aws_region
  s3_access_key_id     = module.iam.s3_access_key_id
  s3_secret_access_key = module.iam.s3_secret_access_key
}

# -----------------------------------------------------------------------------
# IAM
# -----------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  project_name  = var.project_name
  environment   = var.environment
  secrets_arns  = module.secrets.secret_arns
  s3_bucket_arn = module.s3.bucket_arn
}

# -----------------------------------------------------------------------------
# MongoDB on EC2
# -----------------------------------------------------------------------------
module "mongodb" {
  source = "./modules/mongodb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.private_subnet_ids[0]
  security_group_id = aws_security_group.ecs_tasks.id
  mongo_username    = var.docdb_master_username
  mongo_password    = var.docdb_password
}

# -----------------------------------------------------------------------------
# ECS (Cluster, ALB, Task Definitions, Services)
# -----------------------------------------------------------------------------
module "ecs" {
  source = "./modules/ecs"

  project_name                = var.project_name
  environment                 = var.environment
  aws_region                  = var.aws_region
  vpc_id                      = module.vpc.vpc_id
  public_subnet_ids           = module.vpc.public_subnet_ids
  private_subnet_ids          = module.vpc.private_subnet_ids
  domain_name                 = var.domain_name
  route53_zone_id             = var.route53_zone_id
  ecs_tasks_security_group_id = aws_security_group.ecs_tasks.id

  # Server config
  server_cpu           = var.server_cpu
  server_memory        = var.server_memory
  server_desired_count = var.server_desired_count
  server_image         = ""

  # Client config
  client_cpu           = var.client_cpu
  client_memory        = var.client_memory
  client_desired_count = var.client_desired_count
  client_image         = ""

  # IAM
  ecs_execution_role_arn = module.iam.ecs_execution_role_arn
  ecs_task_role_arn      = module.iam.ecs_task_role_arn

  # Secrets
  secrets_arns = module.secrets.secret_arns

  # MongoDB (for the server task)
  docdb_endpoint            = module.mongodb.private_ip
  docdb_port                = 27017
  docdb_username            = var.docdb_master_username
  docdb_password_secret_arn = module.secrets.docdb_password_secret_arn
}
