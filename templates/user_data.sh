#!/bin/bash
set -euo pipefail

# Enable logging
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting instance bootstrap ==="
date

# Variables from Terraform
PROJECT_NAME="${project_name}"
AWS_REGION="${aws_region}"
OPENWEBUI_PORT="${openwebui_port}"
LITELLM_PORT="${litellm_port}"

# Update system
echo "=== Updating system packages ==="
apt-get update
apt-get upgrade -y

# Install required packages
echo "=== Installing required packages ==="
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    jq \
    unzip \
    python3-pip

# Install AWS CLI v2
echo "=== Installing AWS CLI ==="
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install Docker
echo "=== Installing Docker ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start Docker
systemctl enable docker
systemctl start docker

# Create app directories
echo "=== Creating application directories ==="
mkdir -p /opt/ai-platform/{litellm,openwebui,data}
cd /opt/ai-platform

# Fetch parameters from SSM
echo "=== Fetching parameters from SSM ==="
get_param() {
    aws ssm get-parameter --name "$1" --with-decryption --query 'Parameter.Value' --output text --region "$AWS_REGION"
}

DB_CONNECTION_STRING=$(get_param "/$PROJECT_NAME/db/connection_string")
OPENROUTER_API_KEY=$(get_param "/$PROJECT_NAME/openrouter/api_key")
OPENROUTER_BASE_URL=$(get_param "/$PROJECT_NAME/openrouter/base_url")
LITELLM_MASTER_KEY=$(get_param "/$PROJECT_NAME/litellm/master_key")
LITELLM_MODELS=$(get_param "/$PROJECT_NAME/litellm/models")
DEFAULT_MODEL=$(get_param "/$PROJECT_NAME/litellm/default_model")
SYSTEM_PROMPT=$(get_param "/$PROJECT_NAME/config/system_prompt")
OPENWEBUI_ADMIN_EMAIL=$(get_param "/$PROJECT_NAME/openwebui/admin_email")
OPENWEBUI_ADMIN_PASSWORD=$(get_param "/$PROJECT_NAME/openwebui/admin_password")
OPENWEBUI_ADMIN_NAME=$(get_param "/$PROJECT_NAME/openwebui/admin_name")

# Create LiteLLM config
echo "=== Creating LiteLLM configuration ==="
cat > /opt/ai-platform/litellm/config.yaml << 'LITELLM_CONFIG'
model_list:
LITELLM_CONFIG

# Parse models JSON and add to config
echo "$LITELLM_MODELS" | jq -c '.[]' | while read -r model; do
    model_name=$(echo "$model" | jq -r '.model_name')
    provider=$(echo "$model" | jq -r '.litellm_provider')
    model_id=$(echo "$model" | jq -r '.model_id')
    
    cat >> /opt/ai-platform/litellm/config.yaml << EOF
  - model_name: $model_name
    litellm_params:
      model: openrouter/$model_id
      api_key: os.environ/OPENROUTER_API_KEY
      api_base: $OPENROUTER_BASE_URL
EOF
done

# Add litellm settings
cat >> /opt/ai-platform/litellm/config.yaml << EOF

litellm_settings:
  drop_params: true
  set_verbose: true

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL
EOF

echo "=== LiteLLM config created ==="
cat /opt/ai-platform/litellm/config.yaml

# Create docker-compose.yml
echo "=== Creating docker-compose.yml ==="
cat > /opt/ai-platform/docker-compose.yml << EOF
version: '3.8'

services:
  litellm:
    image: ghcr.io/berriai/litellm:main-latest
    container_name: litellm
    restart: unless-stopped
    ports:
      - "$LITELLM_PORT:4000"
    volumes:
      - ./litellm/config.yaml:/app/config.yaml:ro
    environment:
      - LITELLM_MASTER_KEY=$LITELLM_MASTER_KEY
      - OPENROUTER_API_KEY=$OPENROUTER_API_KEY
      - DATABASE_URL=$DB_CONNECTION_STRING
      - LITELLM_LOG=INFO
    command: ["--config", "/app/config.yaml", "--port", "4000", "--detailed_debug"]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 120s

  openwebui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: openwebui
    restart: unless-stopped
    ports:
      - "$OPENWEBUI_PORT:8080"
    volumes:
      - ./openwebui/data:/app/backend/data
    environment:
      - OPENAI_API_BASE_URL=http://litellm:4000/v1
      - OPENAI_API_KEY=$LITELLM_MASTER_KEY
      - WEBUI_SECRET_KEY=$(openssl rand -hex 32)
      - DATABASE_URL=$DB_CONNECTION_STRING
      - WEBUI_AUTH=True
      - DEFAULT_MODELS=$DEFAULT_MODEL
      - ENABLE_SIGNUP=true
      - WEBUI_NAME=AI Platform
    depends_on:
      litellm:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 120s

networks:
  default:
    name: ai-platform-network
EOF

# Create admin user initialization script
echo "=== Creating admin user initialization script ==="
cat > /opt/ai-platform/init-admin.py << 'ADMIN_SCRIPT'
#!/usr/bin/env python3
import os
import sys
import time
import requests
import json

OPENWEBUI_URL = f"http://localhost:{os.environ.get('OPENWEBUI_PORT', '3000')}"
MAX_RETRIES = 30
RETRY_DELAY = 10

def wait_for_openwebui():
    """Wait for OpenWebUI to be ready"""
    for i in range(MAX_RETRIES):
        try:
            response = requests.get(f"{OPENWEBUI_URL}/health", timeout=5)
            if response.status_code == 200:
                print("OpenWebUI is ready!")
                return True
        except Exception as e:
            print(f"Waiting for OpenWebUI... ({i+1}/{MAX_RETRIES})")
        time.sleep(RETRY_DELAY)
    return False

def create_admin_user():
    """Create admin user via signup endpoint"""
    admin_email = os.environ.get('ADMIN_EMAIL')
    admin_password = os.environ.get('ADMIN_PASSWORD')
    admin_name = os.environ.get('ADMIN_NAME', 'Admin')
    
    if not admin_email or not admin_password:
        print("Admin credentials not provided, skipping admin creation")
        return False
    
    # Try to signup (first user becomes admin)
    signup_data = {
        "email": admin_email,
        "password": admin_password,
        "name": admin_name
    }
    
    try:
        response = requests.post(
            f"{OPENWEBUI_URL}/api/v1/auths/signup",
            json=signup_data,
            timeout=30
        )
        
        if response.status_code == 200:
            print(f"Admin user created successfully: {admin_email}")
            return True
        elif response.status_code == 400:
            # User might already exist
            print(f"Admin user might already exist: {response.text}")
            return True
        else:
            print(f"Failed to create admin user: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"Error creating admin user: {e}")
        return False

if __name__ == "__main__":
    if wait_for_openwebui():
        # Small delay to ensure DB is fully ready
        time.sleep(5)
        create_admin_user()
    else:
        print("OpenWebUI did not become ready in time")
        sys.exit(1)
ADMIN_SCRIPT

chmod +x /opt/ai-platform/init-admin.py

# Start services
echo "=== Starting services ==="
cd /opt/ai-platform
docker compose up -d

# Wait for services to start
echo "=== Waiting for services to initialize ==="
sleep 30

# Initialize admin user
echo "=== Initializing admin user ==="
pip3 install requests
OPENWEBUI_PORT=$OPENWEBUI_PORT \
ADMIN_EMAIL="$OPENWEBUI_ADMIN_EMAIL" \
ADMIN_PASSWORD="$OPENWEBUI_ADMIN_PASSWORD" \
ADMIN_NAME="$OPENWEBUI_ADMIN_NAME" \
python3 /opt/ai-platform/init-admin.py || echo "Admin initialization completed (may have already existed)"

# Create systemd service for docker compose
echo "=== Creating systemd service ==="
cat > /etc/systemd/system/ai-platform.service << EOF
[Unit]
Description=AI Platform (OpenWebUI + LiteLLM)
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/ai-platform
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ai-platform.service

# Install LangGraph dependencies (optional - for future use)
echo "=== Installing LangGraph dependencies ==="
pip3 install langgraph langchain langchain-openai

# Final status
echo "=== Bootstrap complete ==="
echo "OpenWebUI: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):$OPENWEBUI_PORT"
echo "LiteLLM: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):$LITELLM_PORT"

docker compose ps
echo "=== Done ==="
