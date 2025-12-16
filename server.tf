# server.tf

# ---------------------------------------------------------------------
# 1. Infrastructure Requirements (AMI, IAM, Security Groups)
# ---------------------------------------------------------------------

data "aws_ami" "al2023_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

resource "aws_iam_role" "compute_server" {
  name = "${local.cluster_name}-compute-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.compute_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "compute_server" {
  name = "${local.cluster_name}-compute-server-policy"
  role = aws_iam_role.compute_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:DeleteParameter",
          "ssm:DescribeParameters"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.ai_storage.arn}",
          "${aws_s3_bucket.ai_storage.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "compute_server" {
  name = "${local.cluster_name}-compute-server-profile"
  role = aws_iam_role.compute_server.name
}

resource "aws_security_group" "compute_server" {
  name        = "${local.cluster_name}-compute-server-sg"
  description = "Security group for K3s Server"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.cluster_name}-compute-server-sg"
  }
}

# ---------------------------------------------------------------------
# 2. Static IP & EC2 Instance Configuration
# ---------------------------------------------------------------------

resource "aws_eip" "k3s_server" {
  domain = "vpc"
  tags = {
    Name = "${local.cluster_name}-k3s-eip"
  }
}

resource "aws_eip_association" "k3s_server" {
  instance_id   = aws_instance.k3s_server.id
  allocation_id = aws_eip.k3s_server.id
}

locals {
  user_data = base64encode(templatefile("user-data.sh", {
    k3s_token    = random_password.k3s_token.result
    db_endpoint  = "postgres://${aws_db_instance.postgres.username}:${random_password.db_password.result}@${aws_db_instance.postgres.endpoint}/${aws_db_instance.postgres.db_name}"
    project_name = var.project_name
    environment  = var.environment
    region       = var.aws_region
    PUBLIC_IP    = aws_eip.k3s_server.public_ip

  }))
}

resource "aws_instance" "k3s_server" {
  ami                         = data.aws_ami.al2023_arm.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.compute_server.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.compute_server.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  instance_market_options {
    market_type = "spot"
    spot_options {
      instance_interruption_behavior = "stop"
      spot_instance_type             = "persistent"
    }
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 75
    encrypted             = true
    delete_on_termination = false
  }

  user_data_base64                   = local.user_data

  tags = {
    Name = "${local.cluster_name}-k3s-server"
  }
}

# Persistent EBS volume for K3s data
resource "aws_ebs_volume" "k3s_data" {
  availability_zone = aws_subnet.public[0].availability_zone
  size              = 100
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${local.cluster_name}-k3s-data"
  }
}

resource "aws_volume_attachment" "k3s_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.k3s_data.id
  instance_id = aws_instance.k3s_server.id
}

# ---------------------------------------------------------------------
# 3. Kubeconfig Management & Wait Logic
# ---------------------------------------------------------------------

resource "aws_ssm_parameter" "k3s_token_param" {
  name  = "/${var.project_name}/${var.environment}/k3s/token"
  type  = "SecureString"
  value = random_password.k3s_token.result
}

resource "aws_ssm_parameter" "kubeconfig_param" {
  name  = "/${var.project_name}/${var.environment}/k3s/kubeconfig"
  type  = "SecureString"
  value = "pending-initialization"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "null_resource" "wait_for_k3s" {
  depends_on = [aws_eip_association.k3s_server, aws_ssm_parameter.kubeconfig_param]

  triggers = {
    instance_id = aws_instance.k3s_server.id
    eip         = aws_eip.k3s_server.public_ip
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
      echo "Waiting for K3s installation on ${aws_eip.k3s_server.public_ip}..."
      MAX_RETRIES=60
      count=0
      
      while [ $count -lt $MAX_RETRIES ]; do
        CURRENT_VAL=$(aws ssm get-parameter \
          --name "/${var.project_name}/${var.environment}/k3s/kubeconfig" \
          --with-decryption \
          --query "Parameter.Value" \
          --output text \
          --region ${var.aws_region} 2>/dev/null || echo "")

        if [[ "$CURRENT_VAL" != "pending-initialization" ]] && [[ "$CURRENT_VAL" != "" ]] && [[ "$CURRENT_VAL" == *"${aws_eip.k3s_server.public_ip}"* ]]; then
          echo "Cluster ready with correct IP."
          exit 0
        fi

        echo "Attempt $count: waiting..."
        sleep 10
        count=$((count + 1))
      done

      echo "Timeout waiting for cluster."
      exit 1
    EOF
  }
}

data "aws_ssm_parameter" "kubeconfig" {
  name       = aws_ssm_parameter.kubeconfig_param.name
  depends_on = [null_resource.wait_for_k3s]
}

resource "local_file" "kubeconfig" {
  depends_on      = [null_resource.wait_for_k3s]
  filename        = "${path.module}/kubeconfig"
  content         = data.aws_ssm_parameter.kubeconfig.value
  file_permission = "0600"
}

# ---------------------------------------------------------------------
# 4. Kubernetes Providers & Base Resources
# ---------------------------------------------------------------------

provider "kubernetes" {
  config_path = local_file.kubeconfig.filename
}

provider "kubectl" {
  config_path      = local_file.kubeconfig.filename
  load_config_file = true
}

resource "kubernetes_namespace" "ai_platform" {
  metadata {
    name = "ai-platform"
    labels = {
      name        = "ai-platform"
      environment = var.environment
    }
  }
}

# ---------------------------------------------------------------------
# 5. Secrets & ConfigMaps 
# ---------------------------------------------------------------------



resource "random_password" "webui_secret_key" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "ai_platform_secrets" {
  metadata {
    name      = "ai-platform-secrets"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    OPENROUTER_API_KEY = var.openrouter_api_key
    WEBUI_SECRET_KEY   = random_password.webui_secret_key.result
    DATABASE_URL       = "postgres://${aws_db_instance.postgres.username}:${random_password.db_password.result}@${aws_db_instance.postgres.endpoint}/${aws_db_instance.postgres.db_name}"
  }

  type = "Opaque"
}

resource "kubernetes_config_map" "litellm_config" {
  metadata {
    name      = "litellm-config"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    "config.yaml" = yamlencode({
      model_list = concat(
        [
          for model in var.litellm_models : {
            model_name = model.model_name
            litellm_params = {
              model    = "openrouter/${model.model_id}"
              api_base = "https://openrouter.ai/api/v1"
              api_key  = "os.environ/OPENROUTER_API_KEY"
            }
          }
        ],
        [
          {
            model_name = "council"
            litellm_params = {
              model               = "council"
              api_base            = "http://council:8000/v1"
              custom_llm_provider = "openai"
            }
          }
        ]
      )
    })
  }
}

resource "kubernetes_config_map" "litellm_personalities" {
  metadata {
    name      = "litellm-personalities"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    "personalities.yaml" = yamlencode({
      for model in var.council_members : model.name => {
        model_id      = model.model_id
        system_prompt = model.system_prompt
      }
    })
  }
}

resource "kubernetes_config_map" "council_config" {
  metadata {
    name      = "council-config"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    "models.yaml" = yamlencode({
      for model in var.council_members : model.name => {
        model_id    = model.name  
        role        = model.role
        max_tokens  = model.max_tokens
        temperature = model.temperature
      }
    })

    "personalities.yaml" = yamlencode({
      for model in var.council_members : model.name => {
        name          = model.name
        system_prompt = model.system_prompt
      }
    })
  }
}
