#!/bin/bash
set -e

GPU_INSTANCES='${gpu_instances}'
LITELLM_MASTER_KEY='${litellm_master_key}'
KNOWLEDGE_BASE_URL='${knowledge_base_url}'

dnf install -y docker
systemctl enable docker
systemctl start docker

mkdir -p /opt/litellm

cat > /opt/litellm/config.yaml << EOF
model_list:
%{ for tier, info in jsondecode(gpu_instances) ~}
  - model_name: ollama-${tier}
    litellm_params:
      model: ollama/llama3.1:8b
      api_base: http://${info.private_ip}:11434
%{ endfor ~}

general_settings:
  master_key: $LITELLM_MASTER_KEY
EOF

docker run -d \
  --name litellm \
  --restart unless-stopped \
  -p 4000:4000 \
  -v /opt/litellm/config.yaml:/app/config.yaml \
  ghcr.io/berriai/litellm:main-latest \
  --config /app/config.yaml

docker run -d \
  --name open-webui \
  --restart unless-stopped \
  -p 8080:8080 \
  -e OPENAI_API_BASE_URL=http://172.17.0.1:4000/v1 \
  -e OPENAI_API_KEY=$LITELLM_MASTER_KEY \
  ghcr.io/open-webui/open-webui:main
