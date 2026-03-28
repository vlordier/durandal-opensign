variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "domain_name" {
  type = string
}

variable "route53_zone_id" {
  type = string
}

# Server
variable "server_cpu" {
  type = number
}

variable "server_memory" {
  type = number
}

variable "server_desired_count" {
  type = number
}

variable "server_image" {
  type = string
}

# Client
variable "client_cpu" {
  type = number
}

variable "client_memory" {
  type = number
}

variable "client_desired_count" {
  type = number
}

variable "client_image" {
  type = string
}

# IAM
variable "ecs_execution_role_arn" {
  type = string
}

variable "ecs_task_role_arn" {
  type = string
}

# Secrets
variable "secrets_arns" {
  type = map(string)
}

# DocumentDB
variable "docdb_endpoint" {
  type = string
}

variable "docdb_port" {
  type = number
}

variable "docdb_username" {
  type = string
}

variable "docdb_password_secret_arn" {
  type = string
}

variable "ecs_tasks_security_group_id" {
  description = "Pre-created ECS tasks security group ID"
  type        = string
}

# -----------------------------------------------------------------------------
# CloudWatch Log Groups
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "server" {
  name              = "/ecs/${var.project_name}/${var.environment}/server"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "client" {
  name              = "/ecs/${var.project_name}/${var.environment}/client"
  retention_in_days = 30
}

# -----------------------------------------------------------------------------
# ECS Cluster
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# -----------------------------------------------------------------------------
# ACM Certificate
# -----------------------------------------------------------------------------
resource "aws_acm_certificate" "this" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# -----------------------------------------------------------------------------
# ALB
# -----------------------------------------------------------------------------
resource "aws_lb" "this" {
  name               = "${var.project_name}-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false
}

resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-alb-sg" }

  lifecycle { create_before_destroy = true }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.this.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.client.arn
  }
}

# HTTP -> HTTPS redirect
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# API path routing to server
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.server.arn
  }

  condition {
    path_pattern {
      values = ["/api/*", "/api", "/health"]
    }
  }
}

# -----------------------------------------------------------------------------
# Target Groups
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "server" {
  name        = "${var.project_name}-${var.environment}-srv"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    matcher             = "200"
  }

  deregistration_delay = 30
}

resource "aws_lb_target_group" "client" {
  name        = "${var.project_name}-${var.environment}-cli"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    matcher             = "200"
  }

  deregistration_delay = 30
}

# -----------------------------------------------------------------------------
# ECS Security Group Ingress Rules (add to shared SG created in root)
# -----------------------------------------------------------------------------
resource "aws_security_group_rule" "server_from_alb" {
  type                     = "ingress"
  description              = "Server port from ALB"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = var.ecs_tasks_security_group_id
}

resource "aws_security_group_rule" "client_from_alb" {
  type                     = "ingress"
  description              = "Client port from ALB"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = var.ecs_tasks_security_group_id
}

# -----------------------------------------------------------------------------
# Server Task Definition
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "server" {
  family                   = "${var.project_name}-${var.environment}-server"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.server_cpu
  memory                   = var.server_memory
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "server"
      image     = var.server_image
      essential = true

      portMappings = [{
        containerPort = 8080
        hostPort      = 8080
        protocol      = "tcp"
      }]

      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "8080" },
        { name = "PARSE_MOUNT", value = "/app" },
        { name = "SERVER_URL", value = "https://${var.domain_name}/api/app" },
        { name = "PUBLIC_URL", value = "https://${var.domain_name}" },
      ]

      secrets = [
        {
          name      = "USE_LOCAL"
          valueFrom = "${var.secrets_arns.app_secrets}:USE_LOCAL::"
        },
        {
          name      = "APP_ID"
          valueFrom = "${var.secrets_arns.app_secrets}:APP_ID::"
        },
        {
          name      = "MASTER_KEY"
          valueFrom = "${var.secrets_arns.master_key}"
        },
        {
          name      = "appName"
          valueFrom = "${var.secrets_arns.app_secrets}:APP_NAME::"
        },
        {
          name      = "MONGODB_URI"
          valueFrom = "${var.secrets_arns.app_secrets}:MONGODB_URI::"
        },
        {
          name      = "DATABASE_URI"
          valueFrom = "${var.secrets_arns.app_secrets}:MONGODB_URI::"
        },
        {
          name      = "DO_SPACE"
          valueFrom = "${var.secrets_arns.app_secrets}:DO_SPACE::"
        },
        {
          name      = "DO_ENDPOINT"
          valueFrom = "${var.secrets_arns.app_secrets}:DO_ENDPOINT::"
        },
        {
          name      = "DO_BASEURL"
          valueFrom = "${var.secrets_arns.app_secrets}:DO_BASEURL::"
        },
        {
          name      = "DO_REGION"
          valueFrom = "${var.secrets_arns.app_secrets}:DO_REGION::"
        },
        {
          name      = "DO_ACCESS_KEY_ID"
          valueFrom = "${var.secrets_arns.app_secrets}:DO_ACCESS_KEY_ID::"
        },
        {
          name      = "DO_SECRET_ACCESS_KEY"
          valueFrom = "${var.secrets_arns.app_secrets}:DO_SECRET_ACCESS_KEY::"
        },
        {
          name      = "SMTP_ENABLE"
          valueFrom = "${var.secrets_arns.app_secrets}:SMTP_ENABLE::"
        },
        {
          name      = "SMTP_HOST"
          valueFrom = "${var.secrets_arns.app_secrets}:SMTP_HOST::"
        },
        {
          name      = "SMTP_PORT"
          valueFrom = "${var.secrets_arns.app_secrets}:SMTP_PORT::"
        },
        {
          name      = "SMTP_USER_EMAIL"
          valueFrom = "${var.secrets_arns.app_secrets}:SMTP_USER_EMAIL::"
        },
        {
          name      = "SMTP_PASS"
          valueFrom = "${var.secrets_arns.app_secrets}:SMTP_PASS::"
        },
        {
          name      = "MAILGUN_API_KEY"
          valueFrom = "${var.secrets_arns.app_secrets}:MAILGUN_API_KEY::"
        },
        {
          name      = "MAILGUN_DOMAIN"
          valueFrom = "${var.secrets_arns.app_secrets}:MAILGUN_DOMAIN::"
        },
        {
          name      = "MAILGUN_SENDER"
          valueFrom = "${var.secrets_arns.app_secrets}:MAILGUN_SENDER::"
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.server.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "server"
        }
      }
    }
  ])
}

# -----------------------------------------------------------------------------
# Client Task Definition
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "client" {
  family                   = "${var.project_name}-${var.environment}-client"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.client_cpu
  memory                   = var.client_memory
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "client"
      image     = var.client_image
      essential = true

      portMappings = [{
        containerPort = 3000
        hostPort      = 3000
        protocol      = "tcp"
      }]

      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "REACT_APP_SERVERURL", value = "https://${var.domain_name}/api/app" },
        { name = "PUBLIC_URL", value = "https://${var.domain_name}" },
        { name = "REACT_APP_APPID", value = "opensign" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.client.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "client"
        }
      }
    }
  ])
}

# -----------------------------------------------------------------------------
# ECS Services
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "server" {
  name            = "${var.project_name}-${var.environment}-server"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.server.arn
  desired_count   = var.server_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.server.arn
    container_name   = "server"
    container_port   = 8080
  }

  deployment_circuit_breaker {
    enable   = false
    rollback = true
  }

  depends_on = [aws_lb_listener_rule.api]
}

resource "aws_ecs_service" "client" {
  name            = "${var.project_name}-${var.environment}-client"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.client.arn
  desired_count   = var.client_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.client.arn
    container_name   = "client"
    container_port   = 3000
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.https]
}

# -----------------------------------------------------------------------------
# DNS Record (A alias to ALB)
# -----------------------------------------------------------------------------
resource "aws_route53_record" "app" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "server_service_name" {
  value = aws_ecs_service.server.name
}

output "client_service_name" {
  value = aws_ecs_service.client.name
}

output "ecs_tasks_security_group_id" {
  value = var.ecs_tasks_security_group_id
}
