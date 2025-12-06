data "aws_ami" "amazon_linux_2_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-arm64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "random_password" "rancher_admin" {
  length  = 16
  special = false
}

resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

resource "aws_security_group" "rancher_server" {
  name        = "${local.cluster_name}-rancher-server-sg"
  description = "Security group for Rancher Server"
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
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.rancher_node.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.cluster_name}-rancher-server-sg"
  }
}

resource "aws_security_group" "rancher_node" {
  name        = "${local.cluster_name}-rancher-node-sg"
  description = "Security group for Rancher managed nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

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
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                          = "${local.cluster_name}-rancher-node-sg"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
}

resource "aws_iam_role" "rancher_server" {
  name = "${local.cluster_name}-rancher-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "rancher_server" {
  name = "${local.cluster_name}-rancher-server-policy"
  role = aws_iam_role.rancher_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:*", "elasticloadbalancing:*", "ecr:*", "s3:*", "route53:*", "iam:*", "ssm:*"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rancher_server_ssm" {
  role       = aws_iam_role.rancher_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "rancher_server" {
  name = "${local.cluster_name}-rancher-server-profile"
  role = aws_iam_role.rancher_server.name
}

resource "aws_iam_role" "rancher_node" {
  name = "${local.cluster_name}-rancher-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "rancher_node" {
  name = "${local.cluster_name}-rancher-node-policy"
  role = aws_iam_role.rancher_node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:*", "elasticloadbalancing:*", "ecr:*", "s3:*", "route53:*", "ssm:*"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rancher_node_ssm" {
  role       = aws_iam_role.rancher_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "rancher_node" {
  name = "${local.cluster_name}-rancher-node-profile"
  role = aws_iam_role.rancher_node.name
}

resource "aws_ebs_volume" "rancher_data" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 20
  type              = "gp3"
  tags = {
    Name = "${local.cluster_name}-rancher-data"
  }
}

resource "aws_volume_attachment" "rancher_data" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.rancher_data.id
  instance_id = aws_instance.rancher_server.id
}

locals {
  user_data = <<-EOF
#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

yum update -y
yum install -y amazon-ssm-agent socat jq
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Swap
dd if=/dev/zero of=/swapfile bs=1M count=2048
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab

# Mount EBS for Rancher data persistence
mkdir -p /var/lib/rancher
# Wait for EBS to attach
while [ ! -b /dev/xvdf ] && [ ! -b /dev/nvme1n1 ]; do sleep 5; done
DEVICE=$(lsblk -o NAME,SIZE | grep -E "xvdf|nvme1n1" | awk '{print "/dev/"$1}' | head -1)
# Format only if not already formatted
if ! blkid $DEVICE; then
  mkfs.ext4 $DEVICE
fi
mount $DEVICE /var/lib/rancher
echo "$DEVICE /var/lib/rancher ext4 defaults,nofail 0 2" >> /etc/fstab
mkdir -p /var/lib/rancher/etc-rancher
ln -s /var/lib/rancher/etc-rancher /etc/rancher
ls /var/lib/rancher
# ACME
export HOME=/root
curl https://get.acme.sh | sh -s email=${var.email}
mkdir -p /opt/rancher/ssl

/root/.acme.sh/acme.sh --set-default-ca --server zerossl

/root/.acme.sh/acme.sh --issue --standalone \
  --domain rancher.${var.domain_name} \
  --httpport 80 \
  --server zerossl \
  --eab-kid "${var.zerossl_eab_kid}" \
  --eab-hmac-key "${var.zerossl_eab_hmac_key}" \
   --debug || echo true


/root/.acme.sh/acme.sh --install-cert --domain rancher.${var.domain_name} \
  --fullchain-file /opt/rancher/ssl/cert.pem \
  --key-file /opt/rancher/ssl/key.pem

docker run -d --restart=unless-stopped \
  -p 80:80 -p 443:443 \
  --privileged \
  -v /var/lib/rancher/docker:/var/lib/rancher \
  -v /opt/rancher/ssl/cert.pem:/etc/rancher/ssl/cert.pem \
  -v /opt/rancher/ssl/key.pem:/etc/rancher/ssl/key.pem \
  -e CATTLE_BOOTSTRAP_PASSWORD="${random_password.rancher_admin.result}" \
  rancher/rancher:latest \
  --no-cacerts
EOF
}


resource "null_resource" "force_replacement" {
  triggers = {
    user_data     = base64encode(local.user_data)
  }
}
resource "aws_eip" "rancher" {
  domain = "vpc"
  tags = {
    Name = "rancher"
  }
}
resource "aws_eip_association" "rancher" {
  instance_id   = aws_instance.rancher_server.id
  allocation_id = aws_eip.rancher.id
}
resource "aws_instance" "rancher_server" {
  ami                    = data.aws_ami.amazon_linux_2_arm.id
  instance_type          = var.rancher_instance_type
  vpc_security_group_ids = [aws_security_group.rancher_server.id]
  subnet_id              = aws_subnet.public[0].id
  iam_instance_profile   = aws_iam_instance_profile.rancher_server.name

  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type             = "persistent"
      instance_interruption_behavior = "stop"
    }
  }

  lifecycle {
    replace_triggered_by = [null_resource.force_replacement.id]
    ignore_changes       = [instance_market_options]
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  user_data = local.user_data
  tags = {
    Name = "${local.cluster_name}-rancher-server"
  }
}

resource "aws_ssm_parameter" "rancher_admin_password" {
  name  = "/${var.project_name}/${var.environment}/rancher/admin-password"
  type  = "SecureString"
  value = random_password.rancher_admin.result
}

resource "aws_ssm_parameter" "k3s_token" {
  name  = "/${var.project_name}/${var.environment}/k3s/token"
  type  = "SecureString"
  value = random_password.k3s_token.result
}
