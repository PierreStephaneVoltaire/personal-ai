# =============================================================================
# Elastic IP
# =============================================================================
resource "aws_eip" "main" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}

# =============================================================================
# Lambda Function for EIP Association
# =============================================================================
data "archive_file" "lambda_eip" {
  type        = "zip"
  output_path = "${path.module}/.terraform/lambda_eip.zip"

  source {
    content  = <<-EOF
      import boto3
      import json
      import os
      import time

      ec2 = boto3.client('ec2')
      autoscaling = boto3.client('autoscaling')

      def handler(event, context):
          print(f"Received event: {json.dumps(event)}")
          
          allocation_id = os.environ['ALLOCATION_ID']
          asg_name = os.environ['ASG_NAME']
          
          # Get instance ID from the event
          detail = event.get('detail', {})
          instance_id = detail.get('EC2InstanceId')
          
          if not instance_id:
              print("No instance ID found in event")
              return {'statusCode': 400, 'body': 'No instance ID'}
          
          # Wait for instance to be running
          print(f"Waiting for instance {instance_id} to be running...")
          waiter = ec2.get_waiter('instance_running')
          try:
              waiter.wait(
                  InstanceIds=[instance_id],
                  WaiterConfig={'Delay': 5, 'MaxAttempts': 60}
              )
          except Exception as e:
              print(f"Error waiting for instance: {e}")
              return {'statusCode': 500, 'body': str(e)}
          
          # Small delay to ensure network interface is ready
          time.sleep(10)
          
          # Associate EIP
          try:
              response = ec2.associate_address(
                  AllocationId=allocation_id,
                  InstanceId=instance_id,
                  AllowReassociation=True
              )
              print(f"EIP associated successfully: {response}")
              return {'statusCode': 200, 'body': f"EIP associated to {instance_id}"}
          except Exception as e:
              print(f"Error associating EIP: {e}")
              return {'statusCode': 500, 'body': str(e)}
    EOF
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "eip_association" {
  filename         = data.archive_file.lambda_eip.output_path
  source_code_hash = data.archive_file.lambda_eip.output_base64sha256
  function_name    = "${var.project_name}-eip-association"
  role             = aws_iam_role.lambda_eip.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.11"
  timeout          = 120

  environment {
    variables = {
      ALLOCATION_ID = aws_eip.main.allocation_id
      ASG_NAME      = aws_autoscaling_group.main.name
    }
  }

  tags = {
    Name = "${var.project_name}-eip-association"
  }
}

# =============================================================================
# CloudWatch Log Group for Lambda
# =============================================================================
resource "aws_cloudwatch_log_group" "lambda_eip" {
  name              = "/aws/lambda/${aws_lambda_function.eip_association.function_name}"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-lambda-logs"
  }
}

# =============================================================================
# EventBridge Rule for ASG Instance Launch
# =============================================================================
resource "aws_cloudwatch_event_rule" "asg_instance_launch" {
  name        = "${var.project_name}-asg-instance-launch"
  description = "Trigger EIP association when ASG launches a new instance"

  event_pattern = jsonencode({
    source      = ["aws.autoscaling"]
    detail-type = ["EC2 Instance Launch Successful"]
    detail = {
      AutoScalingGroupName = [aws_autoscaling_group.main.name]
    }
  })

  tags = {
    Name = "${var.project_name}-asg-instance-launch"
  }
}

resource "aws_cloudwatch_event_target" "lambda_eip" {
  rule      = aws_cloudwatch_event_rule.asg_instance_launch.name
  target_id = "LambdaEIPAssociation"
  arn       = aws_lambda_function.eip_association.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.eip_association.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.asg_instance_launch.arn
}

# =============================================================================
# Initial EIP Association (for first instance)
# =============================================================================
# This is handled by the Lambda, but we can also use a null_resource for initial setup
resource "null_resource" "initial_eip_association" {
  depends_on = [
    aws_autoscaling_group.main,
    aws_lambda_function.eip_association
  ]

  provisioner "local-exec" {
    command = <<-EOF
      echo "Waiting for ASG to launch instance..."
      sleep 60
      echo "EIP will be automatically associated by Lambda function"
    EOF
  }
}
