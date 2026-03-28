variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "mongo_username" {
  type      = string
  sensitive = true
}

variable "mongo_password" {
  type      = string
  sensitive = true
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "mongodb" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.medium"
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [var.security_group_id]

  user_data = <<-EOF
#!/bin/bash
set -e

# Install MongoDB Community Edition
cat <<'MONGOREPOS' > /etc/yum.repos.d/mongodb-org.repo
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc
MONGOREPOS

yum install -y mongodb-org

# Configure MongoDB
mkdir -p /var/lib/mongodb /var/log/mongodb
chown -R mongod:mongod /var/lib/mongodb /var/log/mongodb

cat <<'MONGO CONF' > /etc/mongod.conf
net:
  port: 27017
  bindIp: 0.0.0.0
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
security:
  authorization: enabled
MONGO CONF

# Start and enable MongoDB
systemctl start mongod
systemctl enable mongod

# Wait for MongoDB to start
sleep 10

# Create admin user
mongosh --eval "
use admin;
db.createUser({
  user: 'admin',
  pwd: '${var.mongo_password}',
  roles: [{ role: 'root', db: 'admin' }]
});
"

# Create application user and database
mongosh --eval "
use admin;
db.auth('admin', '${var.mongo_password}');
db.createUser({
  user: '${var.mongo_username}',
  pwd: '${var.mongo_password}',
  roles: [{ role: 'readWrite', db: 'opensign' }]
});
"
EOF

  tags = {
    Name = "${var.project_name}-${var.environment}-mongodb"
  }

  lifecycle {
    create_before_destroy = true
  }
}

output "private_ip" {
  value = aws_instance.mongodb.private_ip
}

output "public_ip" {
  value = aws_instance.mongodb.public_ip
}

output "instance_id" {
  value = aws_instance.mongodb.id
}
