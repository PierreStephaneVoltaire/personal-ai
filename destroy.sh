#!/bin/bash
set -e

echo "=== Destroying AI Platform Infrastructure ==="

echo "Step 1/4: AI Platform Apps"
cd stacks/ai-platform-apps
terraform init
terraform destroy -auto-approve
cd ../..

echo "Step 2/4: Kubernetes Base"
cd stacks/kubernetes-base
terraform init
terraform destroy -auto-approve
cd ../..

echo "Step 3/4: Rancher Cluster"
cd stacks/rancher-cluster
terraform init
terraform destroy -auto-approve
cd ../..

echo "Step 4/4: Base Infrastructure"
cd infrastructure
terraform init
terraform destroy -auto-approve
cd ..

echo "=== Destruction Complete ==="
