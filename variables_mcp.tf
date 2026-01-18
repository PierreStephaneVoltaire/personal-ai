variable "mcp_servers" {
  description = "Map of MCP servers to deploy"
  type = map(object({
    port    = number
    command = list(string)
    args    = list(string)
    image   = optional(string) # Optional override if we want to use a different image later, currently all use the built one
  }))
  default = {
    filesystem = {
      port    = 8081
      command = ["supergateway"]
      args    = ["--stdio", "npx -y @modelcontextprotocol/server-filesystem /mnt/fs", "--port", "8081"]
    }
    aws_docs = {
      port    = 8082
      command = ["supergateway"]
      args    = ["--stdio", "uvx awslabs.aws-documentation-mcp-server", "--port", "8082"]
    }
    terraform = {
      port    = 8083
      command = ["supergateway"]
      args    = ["--stdio", "uvx awslabs.terraform-mcp-server", "--port", "8083"]
    }
    eks = {
      port    = 8084
      command = ["supergateway"]
      args    = ["--stdio", "uvx awslabs.eks-mcp-server", "--port", "8084"]
    }
    ecs = {
      port    = 8085
      command = ["supergateway"]
      args    = ["--stdio", "uvx ecs-mcp-server", "--port", "8085"]
    }
    serverless = {
      port    = 8086
      command = ["supergateway"]
      args    = ["--stdio", "uvx awslabs.aws-serverless-mcp-server", "--port", "8086"]
    }
    kubernetes = {
      port    = 8187
      command = ["kubernetes-mcp-server"]
      args    = ["--port", "8187", "--disable-multi-cluster", "--kubeconfig", "/root/.kube/config", "--stateless"]
    }
    cost_explorer = {
      port    = 8089
      command = ["supergateway"]
      args    = ["--stdio", "uvx awslabs.cost-explorer-mcp-server", "--port", "8089"]
    }
    cloudwatch = {
      port    = 8090
      command = ["supergateway"]
      args    = ["--stdio", "uvx awslabs.cloudwatch-mcp-server", "--port", "8090"]
    }
    bedrock = {
      port    = 8092
      command = ["supergateway"]
      args    = ["--stdio", "uvx awslabs.bedrock-kb-retrieval-mcp-server", "--port", "8092"]
    }
    pricing = {
      port    = 8093
      command = ["supergateway"]
      args    = ["--stdio", "uvx awslabs.aws-pricing-mcp-server", "--port", "8093"]
    }
    billing = {
      port    = 8094
      command = ["supergateway"]
      args    = ["--stdio", "uvx awslabs.billing-cost-management-mcp-server", "--port", "8094"]
    }
    iac = {
      port    = 8095
      command = ["supergateway"]
      args    = ["--stdio", "uvx awslabs.aws-iac-mcp-server", "--port", "8095"]
    }
    core = {
      port    = 8096
      command = ["supergateway"]
      args    = ["--stdio", "uvx awslabs.core-mcp-server", "--port", "8096"]
    }
  }
}
