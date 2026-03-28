# OpenSign AWS Deployment (IaC)

Infrastructure-as-Code to deploy [OpenSign](https://github.com/OpenSignLabs/OpenSign) on AWS using Terraform.

## Architecture

```
Internet
   |
 [ALB]  (Application Load Balancer - HTTPS via ACM)
  /   \
 /api  /*
 /       \
[Server]  [Client]
 ECS Fargate  ECS Fargate
 (Node.js)    (React/Nginx)
    |            |
 [DocumentDB]  [S3]
 (MongoDB)     (Documents)
```

**Components:**

- **VPC** — 2 AZs, public + private subnets, NAT Gateway
- **ECS Fargate** — Server (Parse Server) + Client (React SPA)
- **ALB** — Routes `/api/*` to server, everything else to client
- **DocumentDB** — MongoDB-compatible database (1 instance by default)
- **S3** — Document/file storage bucket
- **ECR** — Container image registries
- **Secrets Manager** — App secrets (master key, MongoDB password, etc.)
- **CloudWatch** — Log groups for ECS tasks
- **ACM** — TLS certificate (DNS-validated)

## Prerequisites

- [Terraform](https://www.developer.hashicorp.com/terraform/install) >= 1.5
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- A Route 53 hosted zone (for TLS certificate validation)
- Docker (for building and pushing images)

## Quick Start

### 1. Configure

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 3. Build & Push Docker Images

```bash
# Get ECR login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# Build and push server
docker build -t opensign-server -f <path-to-OpenSign>/apps/OpenSignServer/Dockerhubfile <path-to-OpenSign>
docker tag opensign-server:latest <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/opensign-server:latest
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/opensign-server:latest

# Build and push client
docker build -t opensign-client -f <path-to-OpenSign>/apps/OpenSign/Dockerhubfile <path-to-OpenSign>
docker tag opensign-client:latest <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/opensign-client:latest
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/opensign-client:latest
```

Or use the Makefile:

```bash
make build-push OPENSIGN_REPO=/path/to/OpenSign
```

### 4. Update ECS Services (after image push)

```bash
make update-services
```

### 5. Access

The app will be available at `https://<your_domain>`.

## CI/CD

The included GitHub Actions workflow (`.github/workflows/deploy.yml`) automates:

1. Building Docker images on push to `main`
2. Pushing images to ECR
3. Updating ECS task definitions (force new deployment)

See [CI/CD Setup](#cicd-setup) below for required secrets.

## CI/CD Setup

Add these secrets to your GitHub repo:

| Secret                  | Description                                      |
| ----------------------- | ------------------------------------------------ |
| `AWS_ACCESS_KEY_ID`     | AWS IAM access key                               |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key                               |
| `AWS_REGION`            | e.g. `us-east-1`                                 |
| `ECR_REGISTRY`          | e.g. `123456789.dkr.ecr.us-east-1.amazonaws.com` |
| `ECS_CLUSTER_NAME`      | From terraform output                            |
| `ECS_SERVER_SERVICE`    | From terraform output                            |
| `ECS_CLIENT_SERVICE`    | From terraform output                            |

## Cost Estimate (us-east-1, default config)

| Resource                              | Estimated Monthly Cost |
| ------------------------------------- | ---------------------- |
| ECS Fargate (2 tasks, 0.5 vCPU, 1GB)  | ~$30                   |
| DocumentDB (db.t3.medium, 1 instance) | ~$95                   |
| ALB                                   | ~$20 + data            |
| NAT Gateway                           | ~$35 + data            |
| S3                                    | ~$0.023/GB             |
| **Total baseline**                    | **~$180/month**        |

> To reduce costs, see `variables.tf` for options like single-AZ or smaller instance sizes.

## File Structure

```
.
├── main.tf                  # Root module orchestration
├── variables.tf             # Input variables
├── outputs.tf               # Output values
├── terraform.tfvars.example # Example configuration
├── Makefile                 # Common operations
├── modules/
│   ├── vpc/                 # VPC, subnets, NAT, IGW, security groups
│   ├── ecr/                 # ECR repositories
│   ├── docdb/               # DocumentDB cluster + instance
│   ├── s3/                  # S3 bucket for documents
│   ├── ecs/                 # ECS cluster, task defs, services, ALB
│   ├── iam/                 # IAM roles and policies
│   └── secrets/             # Secrets Manager secrets
└── .github/workflows/
    └── deploy.yml           # GitHub Actions CI/CD
```
