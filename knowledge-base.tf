resource "aws_s3_bucket" "knowledge_base" {
  count  = var.enable_knowledge_base ? 1 : 0
  bucket = "${var.project_name}-knowledge-base-${data.aws_caller_identity.current.account_id}"

  tags = { Name = "${var.project_name}-knowledge-base" }
}

resource "aws_s3_bucket_versioning" "knowledge_base" {
  count  = var.enable_knowledge_base ? 1 : 0
  bucket = aws_s3_bucket.knowledge_base[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_security_group" "knowledge_base" {
  count  = var.enable_knowledge_base ? 1 : 0
  name   = "${var.project_name}-kb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.controller.id]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-kb-sg" }
}

resource "aws_instance" "knowledge_base" {
  count                  = var.enable_knowledge_base ? 1 : 0
  ami                    = local.controller_ami
  instance_type          = var.knowledge_base_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.knowledge_base[0].id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size = var.knowledge_base_volume_size_gb
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/modules/knowledge-base/userdata.sh", {
    s3_bucket = aws_s3_bucket.knowledge_base[0].bucket
  }))

  tags = { Name = "${var.project_name}-knowledge-base" }
}
