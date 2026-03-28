OPENSIGN_REPO ?= ../OpenSign
AWS_REGION     ?= $(shell terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
ACCOUNT_ID     ?= $(shell aws sts get-caller-identity --query Account --output text)

ECR_SERVER_URL ?= $(shell terraform output -raw ecr_server_repository_url)
ECR_CLIENT_URL ?= $(shell terraform output -raw ecr_client_repository_url)

.PHONY: help init plan apply destroy build-push update-services login-ecr

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform
	terraform init

plan: ## Run Terraform plan
	terraform plan

apply: ## Apply Terraform changes
	terraform apply

destroy: ## Destroy all infrastructure
	terraform destroy

login-ecr: ## Login to ECR
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

build-push: login-ecr ## Build and push Docker images to ECR
	@echo "Building and pushing server image..."
	docker build -t opensign-server -f $(OPENSIGN_REPO)/apps/OpenSignServer/Dockerhubfile $(OPENSIGN_REPO)
	docker tag opensign-server:latest $(ECR_SERVER_URL):latest
	docker tag opensign-server:latest $(ECR_SERVER_URL):$$(git -C $(OPENSIGN_REPO) rev-parse --short HEAD)
	docker push $(ECR_SERVER_URL):latest
	docker push $(ECR_SERVER_URL):$$(git -C $(OPENSIGN_REPO) rev-parse --short HEAD)
	@echo "Building and pushing client image..."
	docker build -t opensign-client -f $(OPENSIGN_REPO)/apps/OpenSign/Dockerhubfile $(OPENSIGN_REPO)
	docker tag opensign-client:latest $(ECR_CLIENT_URL):latest
	docker tag opensign-client:latest $(ECR_CLIENT_URL):$$(git -C $(OPENSIGN_REPO) rev-parse --short HEAD)
	docker push $(ECR_CLIENT_URL):latest
	docker push $(ECR_CLIENT_URL):$$(git -C $(OPENSIGN_REPO) rev-parse --short HEAD)

update-services: ## Force new ECS deployment (pick up new images)
	@echo "Updating server service..."
	aws ecs update-service \
		--cluster $$(terraform output -raw ecs_cluster_name) \
		--service $$(terraform output -raw ecs_server_service_name) \
		--force-new-deployment \
		--region $(AWS_REGION)
	@echo "Updating client service..."
	aws ecs update-service \
		--cluster $$(terraform output -raw ecs_cluster_name) \
		--service $$(terraform output -raw ecs_client_service_name) \
		--force-new-deployment \
		--region $(AWS_REGION)

logs-server: ## Tail server logs
	aws logs tail /ecs/opensign/prod/server --follow --region $(AWS_REGION)

logs-client: ## Tail client logs
	aws logs tail /ecs/opensign/prod/client --follow --region $(AWS_REGION)

deploy: apply build-push update-services ## Full deploy: infra + images + services
