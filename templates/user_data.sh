#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting instance bootstrap ==="
date

# Variables from Terraform
PROJECT_NAME="${project_name}"
AWS_REGION="${aws_region}"

# Update and install packages
echo "=== Installing packages ==="
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release jq unzip gettext-base

# AWS CLI
echo "=== Installing AWS CLI ==="
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Docker
echo "=== Installing Docker ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker
systemctl start docker

# Create directories
echo "=== Creating directories ==="
mkdir -p /opt/${project_name}/{mcpo,litellm,openwebui/data,workspace}
cd /opt/${project_name}

# Fetch SSM parameters
echo "=== Fetching SSM parameters ==="
get_param() {
    aws ssm get-parameter --name "$1" --with-decryption --query 'Parameter.Value' --output text --region "$AWS_REGION"
}

export DB_CONNECTION_STRING=$(get_param "/$PROJECT_NAME/db/connection_string")
export OPENROUTER_API_KEY=$(get_param "/$PROJECT_NAME/openrouter/api_key")
export OPENROUTER_BASE_URL=$(get_param "/$PROJECT_NAME/openrouter/base_url")
export LITELLM_MASTER_KEY=$(get_param "/$PROJECT_NAME/litellm/master_key")
export LITELLM_MODELS=$(get_param "/$PROJECT_NAME/litellm/models")
export SYSTEM_PROMPT=$(get_param "/$PROJECT_NAME/config/system_prompt")
export WEBUI_SECRET_KEY=$(openssl rand -hex 32)
echo "Setting MCPO API key..."
echo "MCPO_API_KEY=${mcpo_api_key}" >> /opt/${project_name}/.env


echo "Writing MCPO config..."
cat > /opt/${project_name}/mcpo/config.json <<'MCPO_CONFIG'
${mcpo_config_content}
MCPO_CONFIG


# Generate LiteLLM config
echo "=== Generating LiteLLM config ==="
cat > /opt/${project_name}/litellm/config.yaml << 'EOF'
model_list:
EOF

echo "$LITELLM_MODELS" | jq -c '.[]' | while read -r model; do
    model_name=$(echo "$model" | jq -r '.model_name')
    model_id=$(echo "$model" | jq -r '.model_id')
    
    cat >> /opt/${project_name}/litellm/config.yaml << MODELEOF
  - model_name: $model_name
    litellm_params:
      model: openrouter/$model_id
      api_key: os.environ/OPENROUTER_API_KEY
      api_base: $OPENROUTER_BASE_URL
MODELEOF
done

# Add system prompt to litellm settings
cat >> /opt/${project_name}/litellm/config.yaml << EOF

litellm_settings:
  drop_params: true
  set_verbose: true


general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL
EOF

echo "=== LiteLLM config ==="
cat /opt/${project_name}/litellm/config.yaml

# Write docker-compose from template
echo "=== Writing docker-compose.yml ==="
cat > /opt/${project_name}/docker-compose.yml << 'DOCKEREOF'
${docker_compose_content}
DOCKEREOF

# Substitute environment variables
envsubst < /opt/${project_name}/docker-compose.yml > /opt/${project_name}/docker-compose.yml.tmp
mv /opt/${project_name}/docker-compose.yml.tmp /opt/${project_name}/docker-compose.yml

echo "=== docker-compose.yml ==="
cat /opt/${project_name}/docker-compose.yml

# Start services
echo "=== Starting services ==="
docker compose up -d

# Systemd service
cat > /etc/systemd/system/${project_name}.service << EOF
[Unit]
Description=AI Platform (OpenWebUI + LiteLLM)
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/${project_name}
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ${project_name}.service

echo "=== Bootstrap complete ==="
docker compose ps
