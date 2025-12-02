# =============================================================================
# Networking Outputs
# =============================================================================
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

# =============================================================================
# Access Outputs
# =============================================================================
output "elastic_ip" {
  description = "Elastic IP address for accessing services"
  value       = aws_eip.main.public_ip
}

output "openwebui_url" {
  description = "OpenWebUI URL"
  value       = "http://${aws_eip.main.public_ip}:${var.openwebui_port}"
}

output "litellm_url" {
  description = "LiteLLM API URL"
  value       = "http://${aws_eip.main.public_ip}:${var.litellm_port}"
}

output "litellm_api_base" {
  description = "LiteLLM API base URL for LangGraph/LangChain"
  value       = "http://${aws_eip.main.public_ip}:${var.litellm_port}/v1"
}

# =============================================================================
# Database Outputs
# =============================================================================
output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.postgres.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

# =============================================================================
# Authentication Outputs
# =============================================================================
output "litellm_master_key_parameter" {
  description = "SSM Parameter path for LiteLLM master key"
  value       = aws_ssm_parameter.litellm_master_key.name
}

output "openwebui_admin_email" {
  description = "OpenWebUI admin email"
  value       = var.openwebui_admin_email
}

output "openwebui_admin_password_parameter" {
  description = "SSM Parameter path for OpenWebUI admin password"
  value       = aws_ssm_parameter.openwebui_admin_password.name
}

# =============================================================================
# Infrastructure Outputs
# =============================================================================
output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.main.name
}

output "launch_template_id" {
  description = "Launch template ID"
  value       = aws_launch_template.main.id
}

output "ec2_security_group_id" {
  description = "EC2 security group ID"
  value       = aws_security_group.ec2.id
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

# =============================================================================
# Cost Monitoring Outputs
# =============================================================================
output "budget_name" {
  description = "AWS Budget name for cost monitoring"
  value       = var.enable_budget_alerts && length(var.budget_alert_emails) > 0 ? aws_budgets_budget.monthly[0].name : "Budget alerts disabled (set budget_alert_emails)"
}

output "ssm_session_command" {
  description = "Command to start SSM session to the instance"
  value       = "aws ssm start-session --target $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${aws_autoscaling_group.main.name} --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text)"
}

# =============================================================================
# Usage Instructions
# =============================================================================
output "usage_instructions" {
  description = "How to use the deployed services"
  value       = <<-EOT
    
    ====================================================================
    DEPLOYMENT COMPLETE - AI PLATFORM
    ====================================================================
    
    ACCESSING SERVICES:
    -------------------
    OpenWebUI:  http://${aws_eip.main.public_ip}:${var.openwebui_port}
    LiteLLM:    http://${aws_eip.main.public_ip}:${var.litellm_port}
    
    OPENWEBUI LOGIN:
    ----------------
    Email:    ${var.openwebui_admin_email}
    Password: (retrieve from SSM: ${aws_ssm_parameter.openwebui_admin_password.name})
    
    GET PASSWORDS FROM SSM:
    -----------------------
    aws ssm get-parameter --name "${aws_ssm_parameter.openwebui_admin_password.name}" --with-decryption --query 'Parameter.Value' --output text
    aws ssm get-parameter --name "${aws_ssm_parameter.litellm_master_key.name}" --with-decryption --query 'Parameter.Value' --output text
    
    USING WITH LANGGRAPH/LANGCHAIN:
    -------------------------------
    from langchain_openai import ChatOpenAI
    
    llm = ChatOpenAI(
        base_url="http://${aws_eip.main.public_ip}:${var.litellm_port}/v1",
        api_key="<litellm_master_key>",
        model="mistral-medium"  # or any configured model
    )
    
    CONFIGURED MODELS:
    ------------------
    ${join("\n    ", [for m in var.litellm_models : "- ${m.model_name} (${m.model_id})"])}
    
    INSTANCE ACCESS (via SSM Session Manager):
    ------------------------------------------
    # Get instance ID
    INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names ${aws_autoscaling_group.main.name} \
      --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text)
    
    # Start session
    aws ssm start-session --target $INSTANCE_ID
    
    # Or use AWS Console: EC2 > Instances > Connect > Session Manager
    
    VIEW LOGS (after SSM session):
    ------------------------------
    sudo docker compose -f /opt/${var.project_name}/docker-compose.yml logs -f
    
    COST MONITORING:
    ----------------
    Budget alerts configured: ${var.enable_budget_alerts ? "Yes ($${var.monthly_budget_amount}/month)" : "No"}
    View costs: AWS Console > Billing > Cost Explorer
    Filter by tag: Project = ${var.project_name}
    
    ====================================================================
  EOT
}
