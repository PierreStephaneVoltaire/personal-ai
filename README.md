# OpenWebUI + LiteLLM Infrastructure

A Terraform-managed infrastructure for deploying OpenWebUI with LiteLLM as a proxy to OpenRouter, backed by PostgreSQL RDS for persistence.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                              VPC                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                      Public Subnets                            │  │
│  │                                                                 │  │
│  │   ┌─────────────────────────────────────────────────────────┐  │  │
│  │   │              EC2 Spot Instance (ASG)                     │  │  │
│  │   │   ┌─────────────┐        ┌──────────────┐               │  │  │
│  │   │   │  OpenWebUI  │───────▶│   LiteLLM    │──────────────────────▶ OpenRouter
│  │   │   │   :3000     │        │    :4000     │               │  │  │
│  │   │   └─────────────┘        └──────────────┘               │  │  │
│  │   │          │                      │                        │  │  │
│  │   └──────────┼──────────────────────┼────────────────────────┘  │  │
│  │              │                      │                           │  │
│  │              ▼                      ▼                           │  │
│  │   ┌─────────────────────────────────────────────────────────┐  │  │
│  │   │              RDS PostgreSQL (db.t4g.micro)               │  │  │
│  │   │                    Shared Database                        │  │  │
│  │   └─────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌────────────┐   ┌────────────┐   ┌─────────────────────────────┐  │
│  │ Elastic IP │   │  Lambda    │   │   SSM Parameter Store       │  │
│  │            │◀──│  (EIP      │   │   - OpenRouter API Key      │  │
│  │            │   │   Attach)  │   │   - LiteLLM Master Key      │  │
│  └────────────┘   └────────────┘   │   - DB Credentials          │  │
│                          ▲         │   - Model Config             │  │
│                          │         └─────────────────────────────┘  │
│                   EventBridge                                        │
│                   (ASG Events)        ┌─────────────────────────┐   │
│                                       │   AWS Budgets            │   │
│                                       │   (Cost Alerts)          │   │
│                                       └─────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Features

- **OpenWebUI**: Modern chat interface with conversation persistence
- **LiteLLM**: Unified API proxy supporting multiple models via OpenRouter
- **PostgreSQL RDS**: Persistent storage for conversations and settings
- **Spot Instances**: Cost-effective compute with automatic EIP reassignment
- **Auto Scaling Group**: Automatic instance recovery on spot termination
- **Parameter Store**: Secure storage for API keys and configuration
- **SSM Session Manager**: Secure shell access without SSH/keys
- **AWS Budgets**: Cost monitoring with email alerts
- **LangGraph/LangChain Ready**: LiteLLM exposed for agent frameworks

## Cost Optimization

This setup is designed to minimize costs:

- **No SSH**: Uses SSM Session Manager (no bastion, no key management)
- **Spot Instances**: ~70% cheaper than on-demand
- **Smallest RDS**: db.t4g.micro (~$12/mo)
- **No detailed monitoring**: Basic CloudWatch only
- **No Performance Insights**: Disabled on RDS
- **Minimal log retention**: 7 days for Lambda logs
- **Budget alerts**: Get notified before overspending

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.5.0
3. OpenRouter API key
4. Session Manager plugin (for instance access): https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

## Quick Start

### 1. Clone and Configure

```bash
cd openwebui-litellm-infra

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

### 2. Required Variables

At minimum, you need to set:

```hcl
openrouter_api_key = "sk-or-v1-your-key-here"

# For budget alerts
budget_alert_emails = ["your-email@example.com"]
```

### 3. Deploy

```bash
# Initialize
terraform init

# Review the plan
terraform plan

# Apply
terraform apply
```

### 4. Access Your Services

After deployment completes (5-10 minutes for RDS + instance bootstrap):

```bash
# Get the outputs
terraform output

# Get admin password
aws ssm get-parameter \
  --name "/openwebui-litellm/openwebui/admin_password" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text
```

## Configuration

### Models

Configure your models in `terraform.tfvars`:

```hcl
litellm_models = [
  {
    model_name       = "mistral-medium"    # Your alias
    litellm_provider = "openrouter"
    model_id         = "mistralai/mistral-medium"  # OpenRouter model ID
  },
  # Add more models...
]

default_model = "mistralai/mistral-medium"
```

### Security

Restrict access by IP:

```hcl
allowed_cidr_blocks = ["YOUR_IP/32"]
```

### Cost Monitoring

```hcl
enable_budget_alerts  = true
monthly_budget_amount = 50  # USD
budget_alert_emails   = ["you@example.com"]
```

You'll receive alerts at 50%, 80%, 100% of budget, and when forecasted to exceed.

### Instance Size

For heavier workloads:

```hcl
instance_type    = "t3.large"  # or bigger
root_volume_size = 50
```

## Instance Access (SSM Session Manager)

No SSH keys needed. Access via AWS CLI or Console:

```bash
# Get instance ID
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names openwebui-litellm-asg \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)

# Start session
aws ssm start-session --target $INSTANCE_ID

# Or via AWS Console:
# EC2 > Instances > Select instance > Connect > Session Manager
```

Once connected:

```bash
# View logs
sudo docker compose -f /opt/ai-platform/docker-compose.yml logs -f

# Restart services
sudo docker compose -f /opt/ai-platform/docker-compose.yml restart

# Check status
sudo docker compose -f /opt/ai-platform/docker-compose.yml ps
```

## Using with LangGraph/LangChain

```python
from langchain_openai import ChatOpenAI

# Get your LiteLLM master key from SSM or outputs
LITELLM_KEY = "your-litellm-master-key"
LITELLM_URL = "http://YOUR_EIP:4000/v1"

llm = ChatOpenAI(
    base_url=LITELLM_URL,
    api_key=LITELLM_KEY,
    model="mistral-medium"  # Use your model alias
)

response = llm.invoke("Hello!")
print(response.content)
```

### LangGraph Example

```python
from langgraph.graph import StateGraph, END
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    base_url="http://YOUR_EIP:4000/v1",
    api_key=LITELLM_KEY,
    model="mistral-medium"
)

# Build your graph...
```

## Troubleshooting

### Check Instance Logs

```bash
# Connect via SSM, then:
cat /var/log/user-data.log
sudo docker compose -f /opt/ai-platform/docker-compose.yml logs
```

### Check Service Health

```bash
# LiteLLM
curl http://YOUR_EIP:4000/health

# OpenWebUI
curl http://YOUR_EIP:3000/health
```

### Database Connection

```bash
# Get connection string
aws ssm get-parameter \
  --name "/openwebui-litellm/db/connection_string" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text
```

### Spot Instance Terminated

The Lambda function automatically reassigns the EIP when a new spot instance launches. Check CloudWatch logs:

```bash
aws logs tail /aws/lambda/openwebui-litellm-eip-association --follow
```

## Costs

Estimated monthly costs (us-east-1):

| Resource | Type | Est. Cost |
|----------|------|-----------|
| EC2 Spot (t3.medium) | Spot | ~$10-15/mo |
| RDS (db.t4g.micro) | On-demand | ~$12/mo |
| EBS (30GB gp3) | Storage | ~$3/mo |
| EIP | Allocated | $0 (attached) |
| Data Transfer | Outbound | Variable |
| **Total** | | **~$25-30/mo** |

## Cleanup

```bash
terraform destroy
```

**Note**: RDS has deletion protection in prod. For dev, it's disabled.

## Files Structure

```
openwebui-litellm-infra/
├── versions.tf           # Provider configuration
├── variables.tf          # Input variables
├── vpc.tf                # VPC and networking
├── security_groups.tf    # Security groups (no SSH)
├── rds.tf                # PostgreSQL RDS
├── parameter_store.tf    # SSM Parameters
├── iam.tf                # IAM roles and policies
├── launch_template.tf    # EC2 launch template
├── asg.tf                # Auto Scaling Group
├── eip.tf                # Elastic IP + Lambda
├── cost_monitoring.tf    # AWS Budgets
├── outputs.tf            # Output values
├── terraform.tfvars.example
├── templates/
│   └── user_data.sh      # Instance bootstrap script
└── README.md
```

## License

MIT
