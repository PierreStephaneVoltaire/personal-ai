packer {
  required_plugins {
    docker = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}

variable "image_repository" {
  type = string
}

variable "image_tag" {
  type = string
  default = "latest"
}

source "docker" "mcp_server" {
  image  = "public.ecr.aws/docker/library/node:20"
  commit = true
  changes = [
    "WORKDIR /app",
    "EXPOSE 8081 8082 8083 8084 8085 8086 8087 8088 8089 8090 8091 8092 8093 8094 8095 8096",
    "ENV PATH=/root/.local/bin:/usr/local/bin:$PATH",
    "ENTRYPOINT [\"/bin/bash\"]"
  ]
}

build {
  name = "mcp_server"
  sources = ["source.docker.mcp_server"]

  # Install system dependencies & Python
  provisioner "shell" {
    inline = [
      "apt-get update && apt-get install -y curl unzip ca-certificates git python3 python3-pip python3-venv",
      "rm -rf /var/lib/apt/lists/*",
      "mkdir -p /app"
    ]
  }

  # Install uv (keep in default location and symlink to /usr/local/bin)
  provisioner "shell" {
    inline = [
      "curl -LsSf https://astral.sh/uv/install.sh | sh",
      "ln -s /root/.local/bin/uv /usr/local/bin/uv",
      "ln -s /root/.local/bin/uvx /usr/local/bin/uvx",
      "uv --version",
      "uvx --version"
    ]
  }

  # Install MCP Servers & Tools
  provisioner "shell" {
    environment_vars = [
      "UV_TOOL_BIN_DIR=/usr/local/bin"
    ]
    inline = [
      "uv tool install fastmcp",
      "npm install -g kubernetes-mcp-server",
      "npm install -g @modelcontextprotocol/server-filesystem",
      "npm install -g supergateway",
      # Pre-install AWS MCP servers for faster startup
      "uv tool install awslabs.aws-documentation-mcp-server",
      "uv tool install awslabs.terraform-mcp-server",
      "uv tool install awslabs.eks-mcp-server",
      "uv tool install awslabs.ecs-mcp-server",
      "uv tool install awslabs.aws-serverless-mcp-server",
      "uv tool install awslabs.cost-explorer-mcp-server",
      "uv tool install awslabs.cloudwatch-mcp-server",
      "uv tool install awslabs.amazon-sns-sqs-mcp-server",
      "uv tool install awslabs.bedrock-kb-retrieval-mcp-server",
      "uv tool install awslabs.aws-pricing-mcp-server",
      "uv tool install awslabs.billing-cost-management-mcp-server",
      "uv tool install awslabs.aws-iac-mcp-server",
      "uv tool install awslabs.core-mcp-server"
    ]
  }

  # Install AWS CLI
  provisioner "shell" {
    inline = [
      "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"/awscliv2.zip\"",
      "unzip /awscliv2.zip -d /",
      "/aws/install",
      "rm -rf /awscliv2.zip /aws",
      "aws --version"
    ]
  }

  # Install kubectl
  provisioner "shell" {
    inline = [
      "curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\"",
      "install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl",
      "kubectl version --client"
    ]
  }

  # Install Helm
  provisioner "shell" {
    inline = [
      "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash",
      "helm version"
    ]
  }

  # Create directories
  provisioner "shell" {
    inline = [
      "mkdir -p /mnt/fs",
      "mkdir -p /root/.kube"
    ]
  }

  post-processors {
    post-processor "docker-tag" {
      repository = var.image_repository
      tags       = [var.image_tag, "latest"]
    }
    post-processor "docker-push" {
        ecr_login = true
        login_server = split("/", var.image_repository)[0]
    }
  }
}