# ================= RDS Subnet Group =================
resource "aws_db_subnet_group" "main" {
  name       = "${lower(var.project_name)}-db-subnet-group"
  subnet_ids = [aws_subnet.private_db.id, aws_subnet.private_db2.id]
}

# ================= RDS MySQL =================
resource "aws_db_instance" "app" {
  identifier             = "myapp-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "myappdb"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}

# ================= CloudWatch Dashboard =================
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-Dashboard"
  dashboard_body = jsonencode({
    widgets = [{
      type   = "metric"
      x = 0, y = 0, width = 12, height = 6
      properties = {
        metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.app.name]]
        period  = 300
        stat    = "Average"
        region  = var.aws_region
        title   = "EC2 CPU Utilization"
      }
    }]
  })
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-HighCPU"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  alarm_description = "Triggers when average CPU exceeds 80%"
}
