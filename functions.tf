data "archive_file" "supplement_lookup" {
  count       = var.enable_functions && var.enable_knowledge_base ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/.lambda/supplement_lookup.zip"

  source {
    content  = file("${path.module}/modules/functions/supplement_lookup.py")
    filename = "supplement_lookup.py"
  }
}

resource "aws_lambda_function" "supplement_lookup" {
  count            = var.enable_functions && var.enable_knowledge_base ? 1 : 0
  filename         = data.archive_file.supplement_lookup[0].output_path
  function_name    = "${var.project_name}-supplement-lookup"
  role             = aws_iam_role.lambda.arn
  handler          = "supplement_lookup.lambda_handler"
  source_code_hash = data.archive_file.supplement_lookup[0].output_base64sha256
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      KNOWLEDGE_BASE_URL = "http://${aws_instance.knowledge_base[0].private_ip}:8000"
    }
  }

  tags = { Name = "${var.project_name}-supplement-lookup" }
}

resource "aws_lambda_function_url" "supplement_lookup" {
  count              = var.enable_functions && var.enable_knowledge_base ? 1 : 0
  function_name      = aws_lambda_function.supplement_lookup[0].function_name
  authorization_type = "NONE"
}
