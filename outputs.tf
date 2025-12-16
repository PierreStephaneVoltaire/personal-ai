output "cluster_name" {
  value = local.cluster_name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "k3s_server_ip" {
  value = aws_instance.k3s_server.public_ip
}

output "k3s_token" {
  value     = random_password.k3s_token.result
  sensitive = true
}

output "compute_server_sg_id" {
  value = aws_security_group.compute_server.id
}

output "compute_server_instance_profile" {
  value = aws_iam_instance_profile.compute_server.name
}

output "ami_id" {
  value = data.aws_ami.al2023_arm.id
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


output "aws_region" {
  value = var.aws_region
}

output "k3s_server_id" {
  value = aws_instance.k3s_server.id
}

output "availability_zone" {
  value = data.aws_availability_zones.available.names[0]
}
