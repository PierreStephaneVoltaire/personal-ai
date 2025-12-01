# =============================================================================
# AWS Budget for Cost Monitoring
# =============================================================================
resource "aws_budgets_budget" "monthly" {
  count = var.enable_budget_alerts && length(var.budget_alert_emails) > 0 ? 1 : 0

  name         = "${var.project_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_amount)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Filter to only this project's resources using tags
  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Project$${var.project_name}"]
  }

  # Alert at 50% of budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  # Alert at 80% of budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  # Alert at 100% of budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  # Forecasted to exceed budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_emails
  }

  tags = {
    Name = "${var.project_name}-budget"
  }
}

# =============================================================================
# Cost Allocation Tags (ensure project tag is active)
# =============================================================================
# Note: Cost allocation tags must be activated in the AWS Billing console
# Go to: Billing > Cost allocation tags > Activate "Project" tag

# =============================================================================
# AWS Cost and Usage Report (optional, for detailed analysis)
# =============================================================================
# Uncomment if you want detailed cost reports in S3
# resource "aws_cur_report_definition" "main" {
#   count = var.enable_budget_alerts ? 1 : 0
#
#   report_name                = "${var.project_name}-cost-report"
#   time_unit                  = "DAILY"
#   format                     = "Parquet"
#   compression                = "Parquet"
#   additional_schema_elements = ["RESOURCES"]
#   s3_bucket                  = aws_s3_bucket.cost_reports[0].id
#   s3_prefix                  = "cost-reports"
#   s3_region                  = var.aws_region
#   report_versioning          = "OVERWRITE_REPORT"
# }
