# OpenSign Deployment - Final Steps

## Current Status

The infrastructure is deployed and working correctly, but the backend service is blocked by Docker Hub rate limits. The frontend is accessible at https://opensign.durandal-robotics.com.

## Solution: Using ECR Images

To complete the deployment, we need to build and push the Docker images to ECR repositories, then update Terraform to use those ECR URLs.

### Step-by-step Instructions

1. **Build the Docker Images Locally (on a machine with Docker)**

   ```bash
   # Get ECR repository URLs
   export ECR_REGISTRY="006133138942.dkr.ecr.us-east-1.amazonaws.com"
   export PROJECT_NAME="opensign"

   # Build and push server image
   cd /Users/vincent/Work/OpenSign
   docker build -f apps/OpenSignServer/Dockerhubfile -t ${ECR_REGISTRY}/${PROJECT_NAME}/server:latest .
   docker push ${ECR_REGISTRY}/${PROJECT_NAME}/server:latest

   # Build and push client image
   docker build -f apps/OpenSign/Dockerhubfile -t ${ECR_REGISTRY}/${PROJECT_NAME}/client:latest .
   docker push ${ECR_REGISTRY}/${PROJECT_NAME}/client:latest
   ```

2. **Update Terraform Variables**

   Modify your `terraform.tfvars` file to add the ECR repository URLs:

   ```
   server_image = "006133138942.dkr.ecr.us-east-1.amazonaws.com/opensign/server:latest"
   client_image = "006133138942.dkr.ecr.us-east-1.amazonaws.com/opensign/client:latest"
   ```

   Or alternatively, you can just remove the server_image and client_image variables from your tfvars file entirely, and Terraform will automatically use the ECR repositories.

3. **Apply the Changes**

   ```bash
   cd /Users/vincent/Work/OpenSign-deploy-aws
   terraform apply
   ```

## Alternative Approach (No Docker Needed)

If you don't want to build images locally, you could:

1. Use the existing Docker Hub images directly in Terraform (but this will still hit rate limits)
2. Set up a proxy or mirror for Docker Hub
3. Use a different image registry that doesn't have rate limits

## Important Notes

- The ECR repositories were already created by Terraform
- The ECS services are already configured to use ECR repositories when no explicit image is provided
- The changes made to main.tf ensure that ECR repositories are used instead of Docker Hub
- The frontend is already working correctly and accessible at https://opensign.durandal-robotics.com
- The backend service will start working once the Docker images are pulled from ECR instead of Docker Hub

## Testing the Deployment

After applying the changes:

1. Visit https://opensign.durandal-robotics.com to verify the frontend works
2. Check the ECS services in AWS Console to confirm both server and client are running
3. Test the API endpoints to ensure the backend is responsive
