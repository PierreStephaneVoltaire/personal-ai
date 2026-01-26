locals {
  # Calculate hash of the packer files to trigger builds on change
  mcp_packer_files = fileset("${path.module}/packer", "**")
  mcp_packer_hash  = sha1(join("", [for f in local.mcp_packer_files : filesha1("${path.module}/packer/${f}")]))

  mcp_build_trigger = substr(local.mcp_packer_hash, 0, 16)
}

resource "null_resource" "mcp_build" {
  triggers = {
    dir_sha1 = local.mcp_build_trigger
    repo_url = aws_ecr_repository.mcp_server.repository_url
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/packer"
    command     = <<EOT
      packer init build.pkr.hcl
      packer build -var "image_repository=${aws_ecr_repository.mcp_server.repository_url}" -var "image_tag=${local.mcp_build_trigger}" build.pkr.hcl
    EOT
  }

  depends_on = [aws_ecr_repository.mcp_server]
}

output "mcp_image_tag" {
  value = local.mcp_build_trigger
}
