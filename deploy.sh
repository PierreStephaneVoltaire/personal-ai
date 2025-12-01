#!/bin/bash
set -e

echo "=========================================="
echo "OpenWebUI + LiteLLM Infrastructure Setup"
echo "=========================================="

# Check prerequisites
command -v terraform >/dev/null 2>&1 || { echo "Error: terraform is required but not installed."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "Error: aws-cli is required but not installed."; exit 1; }

# Check AWS credentials
aws sts get-caller-identity >/dev/null 2>&1 || { echo "Error: AWS credentials not configured."; exit 1; }

# Check for tfvars
if [ ! -f "terraform.tfvars" ]; then
    echo ""
    echo "No terraform.tfvars found. Creating from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo ""
    echo "IMPORTANT: Edit terraform.tfvars with your configuration."
    echo "At minimum, set your OpenRouter API key:"
    echo ""
    echo '  openrouter_api_key = "sk-or-v1-your-key-here"'
    echo ""
    read -p "Press Enter to open the file in your editor, or Ctrl+C to exit..."
    ${EDITOR:-vim} terraform.tfvars
fi

echo ""
echo "Initializing Terraform..."
terraform init

echo ""
echo "Creating execution plan..."
terraform plan -out=tfplan

echo ""
read -p "Review the plan above. Apply? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Applying infrastructure..."
terraform apply tfplan

echo ""
echo "=========================================="
echo "Deployment complete!"
echo "=========================================="
echo ""
echo "Wait 5-10 minutes for RDS and instance to fully initialize."
echo ""
echo "Then run: terraform output"
echo ""
