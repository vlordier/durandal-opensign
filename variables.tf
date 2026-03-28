# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------
variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "opensign"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to use (at least 2 for HA)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

# -----------------------------------------------------------------------------
# Domain / TLS
# -----------------------------------------------------------------------------
variable "domain_name" {
  description = "Domain name for the application (e.g. sign.example.com)"
  type        = string
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID for DNS validation and alias record"
  type        = string
}

# -----------------------------------------------------------------------------
# ECS - Server
# -----------------------------------------------------------------------------
variable "server_cpu" {
  description = "CPU units for the server task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512
}

variable "server_memory" {
  description = "Memory (MiB) for the server task"
  type        = number
  default     = 1024
}

variable "server_desired_count" {
  description = "Number of server task instances"
  type        = number
  default     = 1
}

variable "server_image" {
  description = "Docker image for the server (defaults to public Docker Hub image)"
  type        = string
  default     = "opensign/opensignserver:main"
}

# -----------------------------------------------------------------------------
# ECS - Client
# -----------------------------------------------------------------------------
variable "client_cpu" {
  description = "CPU units for the client task"
  type        = number
  default     = 256
}

variable "client_memory" {
  description = "Memory (MiB) for the client task"
  type        = number
  default     = 512
}

variable "client_desired_count" {
  description = "Number of client task instances"
  type        = number
  default     = 1
}

variable "client_image" {
  description = "Docker image for the client (defaults to public Docker Hub image)"
  type        = string
  default     = "opensign/opensign:main"
}

# -----------------------------------------------------------------------------
# DocumentDB
# -----------------------------------------------------------------------------
variable "docdb_instance_class" {
  description = "DocumentDB instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "docdb_instance_count" {
  description = "Number of DocumentDB instances"
  type        = number
  default     = 1
}

variable "docdb_master_username" {
  description = "DocumentDB master username"
  type        = string
  default     = "opensign"
}

variable "docdb_password" {
  description = "DocumentDB master password (keep secret)"
  type        = string
  sensitive   = true
  default     = "OpenSignDB2026!"
}

# -----------------------------------------------------------------------------
# Application Secrets
# -----------------------------------------------------------------------------
variable "app_id" {
  description = "OpenSign APP_ID (must match REACT_APP_APPID)"
  type        = string
  default     = "opensign"
}

variable "master_key" {
  description = "Parse Server master key (keep secret)"
  type        = string
  sensitive   = true
}

variable "app_name" {
  description = "Application name shown in emails"
  type        = string
  default     = "open_sign_server"
}

# -----------------------------------------------------------------------------
# Email (optional)
# -----------------------------------------------------------------------------
variable "smtp_enable" {
  description = "Enable SMTP for email (if false, Mailgun config is used)"
  type        = bool
  default     = false
}

variable "smtp_host" {
  description = "SMTP server host"
  type        = string
  default     = ""
}

variable "smtp_port" {
  description = "SMTP server port"
  type        = number
  default     = 465
}

variable "smtp_user_email" {
  description = "SMTP username/email"
  type        = string
  default     = ""
}

variable "smtp_pass" {
  description = "SMTP password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "mailgun_api_key" {
  description = "Mailgun API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "mailgun_domain" {
  description = "Mailgun domain"
  type        = string
  default     = ""
}

variable "mailgun_sender" {
  description = "Mailgun sender email"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
