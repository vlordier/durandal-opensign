variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "app_id" {
  type = string
}

variable "master_key" {
  type      = string
  sensitive = true
}

variable "app_name" {
  type = string
}

variable "docdb_username" {
  type = string
}

variable "docdb_password" {
  type      = string
  sensitive = true
}

variable "docdb_endpoint" {
  type = string
}

variable "docdb_port" {
  type = number
}

variable "smtp_enable" {
  type    = bool
  default = false
}

variable "smtp_host" {
  type    = string
  default = ""
}

variable "smtp_port" {
  type    = number
  default = 465
}

variable "smtp_user_email" {
  type    = string
  default = ""
}

variable "smtp_pass" {
  type      = string
  sensitive = true
  default   = ""
}

variable "mailgun_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "mailgun_domain" {
  type    = string
  default = ""
}

variable "mailgun_sender" {
  type    = string
  default = ""
}

variable "s3_bucket" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "s3_access_key_id" {
  type      = string
  sensitive = true
}

variable "s3_secret_access_key" {
  type      = string
  sensitive = true
}

# -----------------------------------------------------------------------------
# Individual Secrets
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "master_key" {
  name                    = "${var.project_name}/${var.environment}/master-key"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "master_key" {
  secret_id     = aws_secretsmanager_secret.master_key.id
  secret_string = var.master_key
}

resource "aws_secretsmanager_secret" "docdb_password" {
  name                    = "${var.project_name}/${var.environment}/docdb-password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "docdb_password" {
  secret_id     = aws_secretsmanager_secret.docdb_password.id
  secret_string = var.docdb_password
}

resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "${var.project_name}/${var.environment}/app-secrets"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    APP_ID               = var.app_id
    MASTER_KEY           = var.master_key
    APP_NAME             = var.app_name
    MONGODB_URI          = "mongodb://${var.docdb_username}:${var.docdb_password}@${var.docdb_endpoint}:${var.docdb_port}/opensign?authSource=admin"
    USE_LOCAL            = ""
    DO_SPACE             = var.s3_bucket
    DO_ENDPOINT          = "s3.${var.aws_region}.amazonaws.com"
    DO_BASEURL           = "https://${var.s3_bucket}.s3.${var.aws_region}.amazonaws.com"
    DO_REGION            = var.aws_region
    DO_ACCESS_KEY_ID     = var.s3_access_key_id
    DO_SECRET_ACCESS_KEY = var.s3_secret_access_key
    SMTP_ENABLE          = var.smtp_enable ? "true" : ""
    SMTP_HOST            = var.smtp_host
    SMTP_PORT            = tostring(var.smtp_port)
    SMTP_USER_EMAIL      = var.smtp_user_email
    SMTP_PASS            = var.smtp_pass
    MAILGUN_API_KEY      = var.mailgun_api_key
    MAILGUN_DOMAIN       = var.mailgun_domain
    MAILGUN_SENDER       = var.mailgun_sender
  })
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "secret_arns" {
  value = {
    master_key     = aws_secretsmanager_secret.master_key.arn
    docdb_password = aws_secretsmanager_secret.docdb_password.arn
    app_secrets    = aws_secretsmanager_secret.app_secrets.arn
  }
}

output "docdb_password_secret_arn" {
  value = aws_secretsmanager_secret.docdb_password.arn
}

output "app_secrets_arn" {
  value = aws_secretsmanager_secret.app_secrets.arn
}
