output "controller_instance_id" {
  value = aws_instance.controller.id
}

output "controller_public_ip" {
  value = aws_eip.controller.public_ip
}

output "litellm_master_key" {
  value     = random_password.litellm_master_key.result
  sensitive = true
}

output "gpu_instances" {
  value = {
    for k, v in module.gpu_tier : k => {
      instance_id = v.instance_id
      public_ip   = v.public_ip
      private_ip  = v.private_ip
      vram_gb     = v.vram_gb
      ebs_size_gb = var.gpu_tiers[k].ebs_size_gb
    }
  }
}

output "ssm_connect_commands" {
  value = {
    controller = "aws ssm start-session --target ${aws_instance.controller.id}"
    gpu_tiers  = { for k, v in module.gpu_tier : k => "aws ssm start-session --target ${v.instance_id}" }
  }
}

output "start_instance_lambda_url" {
  value = aws_lambda_function_url.start_instance.function_url
}

output "knowledge_base" {
  value = var.enable_knowledge_base ? {
    instance_id = aws_instance.knowledge_base[0].id
    private_ip  = aws_instance.knowledge_base[0].private_ip
    s3_bucket   = aws_s3_bucket.knowledge_base[0].bucket
    ssm_connect = "aws ssm start-session --target ${aws_instance.knowledge_base[0].id}"
  } : null
}

output "supplement_lookup_url" {
  value = var.enable_functions && var.enable_knowledge_base ? aws_lambda_function_url.supplement_lookup[0].function_url : null
}

output "urls" {
  value = {
    litellm    = "http://${aws_eip.controller.public_ip}:4000"
    openwebui  = "http://${aws_eip.controller.public_ip}:8080"
  }
}
