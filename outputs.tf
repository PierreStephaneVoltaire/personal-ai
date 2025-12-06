output "cluster_name" {
  value = local.cluster_name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "rancher_server_url" {
  value = "https://rancher.${var.domain_name}"
}

output "rancher_server_ip" {
  value = aws_instance.rancher_server.public_ip
}

output "rancher_admin_password" {
  value     = random_password.rancher_admin.result
  sensitive = true
}

output "k3s_token" {
  value     = random_password.k3s_token.result
  sensitive = true
}

output "rancher_server_sg_id" {
  value = aws_security_group.rancher_server.id
}

output "rancher_node_sg_name" {
  value = aws_security_group.rancher_node.name
}

output "rancher_node_instance_profile" {
  value = aws_iam_instance_profile.rancher_node.name
}

output "ami_id" {
  value = data.aws_ami.amazon_linux_2_arm.id
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "rds_database_name" {
  value = aws_db_instance.postgres.db_name
}

output "db_connection_string" {
  value     = "postgresql://${aws_db_instance.postgres.username}:${random_password.db_password.result}@${aws_db_instance.postgres.endpoint}/${aws_db_instance.postgres.db_name}"
  sensitive = true
}

output "s3_bucket" {
  value = aws_s3_bucket.ai_storage.id
}

output "route53_zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "route53_nameservers" {
  value = aws_route53_zone.main.name_servers
}

output "domain_name" {
  value = var.domain_name
}

output "aws_region" {
  value = var.aws_region
}

output "rancher_server_id" {
  value = aws_instance.rancher_server.id
}
