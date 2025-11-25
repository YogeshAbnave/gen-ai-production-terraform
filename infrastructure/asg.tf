# Generate SSH Key Pair
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_openssh
  filename        = "${path.module}/../.ssh/crud-app-key"
  file_permission = "0600"
}

# Save public key locally
resource "local_file" "public_key" {
  content         = tls_private_key.ssh.public_key_openssh
  filename        = "${path.module}/../.ssh/crud-app-key.pub"
  file_permission = "0644"
}

# AWS Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = "crud-app-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "crud-app-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  key_name = aws_key_pair.deployer.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.app.id]
  }

  user_data = base64encode(templatefile("${path.module}/scripts/user_data.sh", {
    dynamodb_table      = aws_dynamodb_table.main.name
    aws_region          = var.aws_region
    s3_bucket_name      = aws_s3_bucket.images.id
    cloudfront_domain   = aws_cloudfront_distribution.images.domain_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "crud-app-instance"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                      = "crud-app-asg"
  vpc_zone_identifier       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  min_size                  = 2
  max_size                  = 10 # Increased from 4
  desired_capacity          = 2

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "crud-app-asg-instance"
    propagate_at_launch = true
  }
}

# Auto Scaling Policy - Scale Up
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "crud-app-scale-up"
  scaling_adjustment     = 2 # Scale up by 2 instances at a time
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 180 # Reduced from 300 for faster scaling
  autoscaling_group_name = aws_autoscaling_group.app.name
}

# CloudWatch Alarm - High CPU
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "crud-app-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1" # Reduced from 2 for faster response
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60" # Reduced from 120 for faster detection
  statistic           = "Average"
  threshold           = "40" # Lowered from 70 to trigger earlier
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}

# Auto Scaling Policy - Scale Down
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "crud-app-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

# CloudWatch Alarm - Low CPU
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "crud-app-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}
