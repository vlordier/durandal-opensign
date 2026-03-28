#!/bin/bash

# Script to build and push OpenSign Docker images to ECR
# This addresses the Docker Hub rate limit issue

set -e

# Configuration
PROJECT_NAME="opensign"
ENVIRONMENT="prod"
AWS_REGION="us-east-1"
ECR_REGISTRY="006133138942.dkr.ecr.us-east-1.amazonaws.com"

# Get ECR repository URLs
SERVER_REPO_URL="${ECR_REGISTRY}/${PROJECT_NAME}/server"
CLIENT_REPO_URL="${ECR_REGISTRY}/${PROJECT_NAME}/client"

echo "Building and pushing OpenSign images to ECR..."

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Build and push server image
echo "Building server image..."
cd /Users/vincent/Work/OpenSign
docker build -f apps/OpenSignServer/Dockerhubfile -t ${SERVER_REPO_URL}:latest .

echo "Pushing server image to ECR..."
docker push ${SERVER_REPO_URL}:latest

# Build and push client image
echo "Building client image..."
cd /Users/vincent/Work/OpenSign
docker build -f apps/OpenSign/Dockerhubfile -t ${CLIENT_REPO_URL}:latest .

echo "Pushing client image to ECR..."
docker push ${CLIENT_REPO_URL}:latest

echo "All images built and pushed successfully!"

# Display the image URIs for reference
echo ""
echo "Image URIs for Terraform:"
echo "Server: ${SERVER_REPO_URL}:latest"
echo "Client: ${CLIENT_REPO_URL}:latest"
