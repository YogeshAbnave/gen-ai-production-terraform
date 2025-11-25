# ALB-based Auto Scaling (more responsive than CPU-based)

# Target Tracking Policy - Request Count Per Target
resource "aws_autoscaling_policy" "target_tracking_alb" {
  name                   = "crud-app-target-tracking-alb"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.app.arn_suffix}"
    }
    target_value = 1000.0 # Scale when requests per target exceed 1000/min
  }
}

# CloudWatch Alarm - High Request Count (backup trigger)
resource "aws_cloudwatch_metric_alarm" "high_requests" {
  alarm_name          = "crud-app-high-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1000"
  alarm_description   = "Triggers when request count is high"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }
}
