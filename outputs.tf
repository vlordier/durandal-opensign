# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------
output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

# -----------------------------------------------------------------------------
# ECR
# -----------------------------------------------------------------------------
output "ecr_server_repository_url" {
  description = "ECR repository URL for the server image"
  value       = module.ecr.server_repository_url
}

output "ecr_client_repository_url" {
  description = "ECR repository URL for the client image"
  value       = module.ecr.client_repository_url
}

# -----------------------------------------------------------------------------
# ECS
# -----------------------------------------------------------------------------
output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.ecs.alb_dns_name
}

output "app_url" {
  description = "Application URL"
  value       = "https://${var.domain_name}"
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_server_service_name" {
  description = "ECS server service name"
  value       = module.ecs.server_service_name
}

output "ecs_client_service_name" {
  description = "ECS client service name"
  value       = module.ecs.client_service_name
}

# -----------------------------------------------------------------------------
# MongoDB
# -----------------------------------------------------------------------------
output "mongodb_endpoint" {
  description = "MongoDB instance endpoint"
  value       = module.mongodb.private_ip
}

# -----------------------------------------------------------------------------
# S3
# -----------------------------------------------------------------------------
output "s3_bucket_name" {
  description = "S3 bucket name for document storage"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = module.s3.bucket_arn
}
