FROM node:20-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:$PATH"

# Install FastMCP
RUN uv pip install --system fastmcp

# Install MCP Servers
# 1. Filesystem
RUN npm install -g @modelcontextprotocol/server-filesystem

# 2. Kubernetes
RUN npm install -g @strowk/mcp-k8s

# Create app directory
WORKDIR /app

# Copy start script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Entrypoint
CMD ["/app/start.sh"]