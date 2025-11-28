# GPU-based Ollama Deployment on AWS

Terraform configuration for multi-tier GPU infrastructure running Ollama with LiteLLM proxy and automatic instance management.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC                                  │
│  ┌─────────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ Controller  │  │ 8GB GPU  │  │ 18GB GPU │  │ 32GB GPU │  │
│  │ (LiteLLM)   │→ │g4dn.xl   │  │ g5.xl    │  │ g5.4xl   │  │
│  │ (OpenWebUI) │  │ (Ollama) │  │ (Ollama) │  │ (Ollama) │  │
│  └─────────────┘  └──────────┘  └──────────┘  └──────────┘  │
│        ↑               ↑              ↑             ↑       │
│        │          [EBS 50GB]    [EBS 100GB]   [EBS 200GB]   │
│        │                                                     │
│  ┌─────────────┐  ┌─────────────────────────────────────┐   │
│  │ Start/Stop  │  │       Knowledge Base (optional)      │   │
│  │  Lambdas    │  │  (ChromaDB + supplements + rules)    │   │
│  └─────────────┘  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## GPU Tiers

| Tier | Instance     | VRAM  | EBS Size | Use Case              |
|------|-------------|-------|----------|------------------------|
| 8gb  | g4dn.xlarge | 16GB  | 50GB     | 7B-13B models         |
| 18gb | g5.xlarge   | 24GB  | 100GB    | 30B-70B models        |
| 32gb | g5.4xlarge  | 48GB  | 200GB    | 70B+ quantized models |

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars - set allowed_cidrs to your IP

terraform init
terraform apply
```

## Accessing Instances (SSM)

No SSH required. Use AWS Systems Manager Session Manager:

```bash
# Get SSM commands for all instances
terraform output ssm_connect_commands

# Connect to controller
aws ssm start-session --target $(terraform output -raw controller_instance_id)

# Connect to GPU instance
aws ssm start-session --target $(terraform output -json gpu_instances | jq -r '.["8gb"].instance_id')
```

## API Usage

```bash
LITELLM_KEY=$(terraform output -raw litellm_master_key)
CONTROLLER=$(terraform output -raw controller_public_ip)

# Chat (auto-starts GPU if needed)
curl http://$CONTROLLER:4000/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LITELLM_KEY" \
  -d '{"model": "ollama-8gb", "messages": [{"role": "user", "content": "Hello"}]}'

# Start GPU manually
curl -X POST "$(terraform output -raw start_instance_lambda_url)" \
  -d '{"tier": "8gb", "wait_for_running": true}'
```

## Knowledge Base

Enable with `enable_knowledge_base = true`. Includes collections for:

- **supplements** - Examine.com supplement guides
- **powerlifting_rules** - IPF/USAPL Technical Rules

### Upload Documents to S3

```bash
S3_BUCKET=$(terraform output -json knowledge_base | jq -r '.s3_bucket')

# Upload supplements
aws s3 cp knowledge-base-documents/supplements/ s3://$S3_BUCKET/documents/supplements/ --recursive

# Upload powerlifting rules
aws s3 cp knowledge-base-documents/powerlifting_rules/ s3://$S3_BUCKET/documents/powerlifting_rules/ --recursive
```

### Ingest Documents

```bash
KB_IP=$(terraform output -json knowledge_base | jq -r '.private_ip')

# Connect via SSM and run ingest
aws ssm start-session --target $(terraform output -json knowledge_base | jq -r '.instance_id')

# Inside the instance:
curl -X POST http://localhost:8000/ingest -H "Content-Type: application/json" -d '{"collection": "supplements"}'
curl -X POST http://localhost:8000/ingest -H "Content-Type: application/json" -d '{"collection": "powerlifting_rules"}'
```

### Query Knowledge Base

```bash
# Via Lambda
LOOKUP_URL=$(terraform output -raw supplement_lookup_url)
curl -X POST "$LOOKUP_URL" \
  -H "Content-Type: application/json" \
  -d '{"query": "creatine dosage timing", "collection": "supplements"}'
```

## Configuration

### GPU Tiers Variable

```hcl
gpu_tiers = {
  "8gb" = {
    instance_type = "g4dn.xlarge"
    vram_gb       = 16
    ebs_size_gb   = 50
  }
  "18gb" = {
    instance_type = "g5.xlarge"
    vram_gb       = 24
    ebs_size_gb   = 100
  }
  "32gb" = {
    instance_type = "g5.4xlarge"
    vram_gb       = 48
    ebs_size_gb   = 200
  }
}
```

### Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `allowed_cidrs` | ["0.0.0.0/0"] | CIDRs allowed to access LiteLLM/OpenWebUI |
| `max_uptime_minutes` | 30 | Auto-stop after this many minutes |
| `enable_knowledge_base` | false | Enable RAG infrastructure |
| `enable_functions` | false | Enable supplement_lookup Lambda |

## Cost Estimates (4 hours daily GPU usage)

| Component | Instance | Hours/Month | Cost |
|-----------|----------|-------------|------|
| Controller | t3.micro | 720 | ~$8 |
| 8GB Tier | g4dn.xlarge | 120 | ~$63 |
| 18GB Tier | g5.xlarge | 120 | ~$120 |
| 32GB Tier | g5.4xlarge | 120 | ~$240 |
| Knowledge Base | t3.medium | 720 | ~$35 |
