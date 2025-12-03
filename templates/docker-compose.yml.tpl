version: '3.8'

services:
  litellm:
    image: ghcr.io/berriai/litellm:main-latest
    container_name: litellm
    restart: unless-stopped
    ports:
      - "${litellm_port}:4000"
    volumes:
      - ./litellm/config.yaml:/app/config.yaml:ro
    environment:
      - LITELLM_MASTER_KEY=$${LITELLM_MASTER_KEY}
      - OPENROUTER_API_KEY=$${OPENROUTER_API_KEY}
      - DATABASE_URL=$${DB_CONNECTION_STRING}
      - LITELLM_LOG=INFO
    command: ["--config", "/app/config.yaml", "--port", "4000"]
  
  tika:
    image: apache/tika:latest
    container_name: tika
    restart: unless-stopped
    ports:
      - "9998:9998"
  
  mcpo:
    image: ghcr.io/open-webui/mcpo:main
    container_name: mcpo
    restart: unless-stopped
    ports:
      - "8000:8000"
    volumes:
      - ./mcpo/config.json:/app/config/config.json:ro
      - /var/run/docker.sock:/var/run/docker.sock
      - ~/.kube:/root/.kube:ro
      - ~/.aws:/root/.aws:ro
      - ./workspace:/workspace
    environment:
      - MCPO_API_KEY=${mcpo_api_key}
    command: ["--config", "/app/config/config.json", "--port", "8000", "--api-key", "${mcpo_api_key}"]
  
  openwebui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: openwebui
    restart: unless-stopped
    ports:
      - "${openwebui_port}:8080"
    volumes:
      - ./openwebui/data:/app/backend/data
    environment:
      - OPENAI_API_BASE_URL=http://litellm:4000/v1
      - OPENAI_API_KEY=$${LITELLM_MASTER_KEY}
      - WEBUI_SECRET_KEY=$${WEBUI_SECRET_KEY}
      - DATABASE_URL=$${DB_CONNECTION_STRING}
      - WEBUI_AUTH=True
      - DEFAULT_MODELS=${default_model}
      - DOCKER=true
      - ENABLE_SIGNUP=true
      - ENABLE_SIGNUP_PASSWORD_CONFIRMATION=true
      - ENABLE_REALTIME_CHAT_SAVE=true
      - WEBUI_NAME=AI Platform
      - CONTENT_EXTRACTION_ENGINE=tika
      - TIKA_SERVER_URL=http://tika:9998
      - STORAGE_PROVIDER=s3
      - S3_BUCKET_NAME=${s3_bucket_name}
      - S3_REGION_NAME=${aws_region}
      - S3_KEY_PREFIX=${s3_key_prefix}
      - VECTOR_DB=pgvector
      - ENABLE_DIRECT_CONNECTIONS=true
      - TOOL_SERVER_CONNECTIONS=[{"type":"openapi","url":"http://mcpo:8000","auth_type":"bearer","key":"${mcpo_api_key}","config":{"enable":true},"info":{"name":"MCP Tools"}}]

    depends_on:
      - litellm
      - tika
      - mcpo

networks:
  default:
    name: ${project_name}-network