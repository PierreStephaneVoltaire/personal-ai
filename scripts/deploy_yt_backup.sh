#!/bin/bash
set -e

# Configuration
REGION="ca-central-1"
REPO_NAME="yt-backup"
DOCKER_DIR="workflow/code"

echo "Deploying yt-backup service..."

# 1. Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$ACCOUNT_ID" ]; then
    echo "Error: Could not get AWS Account ID. Please ensure aws-cli is configured."
    exit 1
fi

ECR_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE_URI="${ECR_URL}/${REPO_NAME}:latest"

echo "Target Image: ${IMAGE_URI}"

# 2. Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region "${REGION}" | docker login --username AWS --password-stdin "${ECR_URL}"

# 3. Create Repository if it doesn't exist (Idempotency check)
# Although Terraform manages this, this ensures we can push even if TF state is desynced or not applied yet.
if ! aws ecr describe-repositories --repository-names "${REPO_NAME}" --region "${REGION}" > /dev/null 2>&1; then
    echo "Repository ${REPO_NAME} not found. Creating..."
    aws ecr create-repository --repository-name "${REPO_NAME}" --region "${REGION}"
else
    echo "Repository ${REPO_NAME} exists."
fi

# 4. Build Docker Image
echo "Building Docker image..."
docker build -t "${REPO_NAME}" "${DOCKER_DIR}"

# 5. Tag and Push
echo "Tagging and Pushing to ECR..."
docker tag "${REPO_NAME}:latest" "${IMAGE_URI}"
docker push "${IMAGE_URI}"

# 6. Restart Kubernetes Deployment
echo "Restarting Kubernetes deployment..."
kubectl rollout restart deployment/yt-backup -n ai-platform

echo "Deployment complete!"
