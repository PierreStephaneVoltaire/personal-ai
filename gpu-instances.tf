module "gpu_tier" {
  source   = "./modules/gpu-tier"
  for_each = var.gpu_tiers

  tier_name            = each.key
  instance_type        = each.value.instance_type
  vram_gb              = each.value.vram_gb
  ebs_size_gb          = each.value.ebs_size_gb
  ami_id               = local.gpu_ami
  subnet_id            = aws_subnet.public.id
  security_group_id    = aws_security_group.gpu.id
  iam_instance_profile = aws_iam_instance_profile.ec2.name
  project_name         = var.project_name
}
