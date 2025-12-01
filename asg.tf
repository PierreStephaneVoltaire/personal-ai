# =============================================================================
# Auto Scaling Group
# =============================================================================
resource "aws_autoscaling_group" "main" {
  name                = "${var.project_name}-asg"
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = aws_subnet.public[*].id

  # Use mixed instances policy for spot
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.main.id
        version            = "$Latest"
      }

      override {
        instance_type = var.instance_type
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "capacity-optimized"
      spot_max_price                           = var.spot_max_price != "" ? var.spot_max_price : null
    }
  }

  # Health checks
  health_check_type         = "EC2"
  health_check_grace_period = 300

  # Instance refresh (for updates)
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
    }
  }

  # Tags
  dynamic "tag" {
    for_each = {
      Name        = "${var.project_name}-instance"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # Lifecycle
  lifecycle {
    create_before_destroy = true
  }
}
