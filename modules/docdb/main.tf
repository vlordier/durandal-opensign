variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "instance_class" {
  type    = string
  default = "db.t3.medium"
}

variable "instance_count" {
  type    = number
  default = 1
}

variable "master_username" {
  type = string
}

variable "master_password" {
  type      = string
  sensitive = true
}

variable "allowed_security_group_id" {
  description = "Security group allowed to connect to DocumentDB"
  type        = string
}

resource "aws_docdb_subnet_group" "this" {
  name       = "${var.project_name}-${var.environment}-docdb"
  subnet_ids = var.private_subnet_ids

  tags = { Name = "${var.project_name}-${var.environment}-docdb-subnet" }
}

resource "aws_docdb_cluster_parameter_group" "this" {
  family      = "docdb5.0"
  name        = "${var.project_name}-${var.environment}-docdb-params"
  description = "DocumentDB parameter group"

  parameter {
    name  = "tls"
    value = "disabled"
  }
}

resource "aws_docdb_cluster" "this" {
  cluster_identifier              = "${var.project_name}-${var.environment}"
  engine                          = "docdb"
  master_username                 = var.master_username
  master_password                 = var.master_password
  db_subnet_group_name            = aws_docdb_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.this.id]
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.this.name
  skip_final_snapshot             = true
  deletion_protection             = false
  storage_encrypted               = true

  tags = { Name = "${var.project_name}-${var.environment}-docdb" }
}

resource "aws_docdb_cluster_instance" "this" {
  count              = var.instance_count
  identifier         = "${var.project_name}-${var.environment}-${count.index}"
  cluster_identifier = aws_docdb_cluster.this.id
  instance_class     = var.instance_class

  tags = { Name = "${var.project_name}-${var.environment}-docdb-${count.index}" }
}

resource "aws_security_group" "this" {
  name_prefix = "${var.project_name}-${var.environment}-docdb-"
  description = "DocumentDB security group"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MongoDB from ECS tasks"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [var.allowed_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-docdb-sg" }

  lifecycle { create_before_destroy = true }
}

output "endpoint" {
  value = aws_docdb_cluster.this.endpoint
}

output "reader_endpoint" {
  value = aws_docdb_cluster.this.reader_endpoint
}

output "port" {
  value = 27017
}

output "cluster_id" {
  value = aws_docdb_cluster.this.id
}
