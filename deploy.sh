#!/bin/bash
set -e

echo "=== Deploying AI Platform Infrastructure ==="

terraform init
terraform apply -auto-approve
cd ..

echo "Step 2/4: Rancher Cluster"
cd stacks/rancher-cluster
terraform init
terraform apply -auto-approve
cd ../..

echo "Step 3/4: Kubernetes Base"
cd stacks/kubernetes-base
terraform init
terraform apply -auto-approve
cd ../..

echo "Step 4/4: AI Platform Apps"
cd stacks/ai-platform-apps
terraform init
terraform apply -auto-approve
cd ../..

echo "=== Deployment Complete ==="
