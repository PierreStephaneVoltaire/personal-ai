data "archive_file" "start_instance" {
  type        = "zip"
  output_path = "${path.module}/.lambda/start_instance.zip"

  source {
    content  = file("${path.module}/modules/lambdas/start_instance.py")
    filename = "start_instance.py"
  }
}

data "archive_file" "stop_instances" {
  type        = "zip"
  output_path = "${path.module}/.lambda/stop_instances.zip"

  source {
    content  = file("${path.module}/modules/lambdas/stop_instances.py")
    filename = "stop_instances.py"
  }
}

resource "aws_lambda_function" "start_instance" {
  filename         = data.archive_file.start_instance.output_path
  function_name    = "${var.project_name}-start-instance"
  role             = aws_iam_role.lambda.arn
  handler          = "start_instance.lambda_handler"
  source_code_hash = data.archive_file.start_instance.output_base64sha256
  runtime          = "python3.11"
  timeout          = 300
  memory_size      = 128

  environment {
    variables = {
      GPU_INSTANCES = jsonencode({
        for k, v in module.gpu_tier : k => {
          instance_id = v.instance_id
          elastic_ip  = v.elastic_ip
          vram_gb     = v.vram_gb
        }
      })
    }
  }

  tags = { Name = "${var.project_name}-start-instance" }
}

resource "aws_lambda_function" "stop_instances" {
  filename         = data.archive_file.stop_instances.output_path
  function_name    = "${var.project_name}-stop-instances"
  role             = aws_iam_role.lambda.arn
  handler          = "stop_instances.lambda_handler"
  source_code_hash = data.archive_file.stop_instances.output_base64sha256
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 128

  environment {
    variables = {
      GPU_INSTANCE_IDS   = jsonencode([for k, v in module.gpu_tier : v.instance_id])
      MAX_UPTIME_MINUTES = tostring(var.max_uptime_minutes)
    }
  }

  tags = { Name = "${var.project_name}-stop-instances" }
}

resource "aws_lambda_function_url" "start_instance" {
  function_name      = aws_lambda_function.start_instance.function_name
  authorization_type = "NONE"
}

resource "aws_cloudwatch_event_rule" "stop_check" {
  name                = "${var.project_name}-stop-check"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "stop_check" {
  rule      = aws_cloudwatch_event_rule.stop_check.name
  target_id = "stop-instances"
  arn       = aws_lambda_function.stop_instances.arn
}

resource "aws_lambda_permission" "stop_check" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_instances.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_check.arn
}
