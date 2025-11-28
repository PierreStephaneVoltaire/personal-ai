resource "aws_instance" "controller" {
  ami                    = local.controller_ami
  instance_type          = var.controller_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.controller.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/controller-userdata.sh", {
    gpu_instances      = jsonencode({ for k, v in module.gpu_tier : k => { instance_id = v.instance_id, private_ip = v.private_ip, vram_gb = v.vram_gb } })
    litellm_master_key = random_password.litellm_master_key.result
    knowledge_base_url = var.enable_knowledge_base ? "http://${aws_instance.knowledge_base[0].private_ip}:8000" : ""
  }))

  tags = { Name = "${var.project_name}-controller" }

  depends_on = [module.gpu_tier]
}

resource "aws_eip" "controller" {
  instance = aws_instance.controller.id
  domain   = "vpc"

  tags = { Name = "${var.project_name}-controller-eip" }
}
