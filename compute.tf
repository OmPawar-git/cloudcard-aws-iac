# ================= S3 =================
resource "aws_s3_bucket" "assets" {
  bucket = var.s3_bucket_name
  tags   = { Name = "${var.project_name}-Assets" }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ================= IAM Role for EC2 =================
resource "aws_iam_role" "ec2_role" {
  name = "EC2-App-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2-App-Profile"
  role = aws_iam_role.ec2_role.name
}

# ================= Latest Amazon Linux AMI =================
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ================= EC2 Launch Template =================
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-Template-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = var.key_pair_name

  iam_instance_profile { name = aws_iam_instance_profile.ec2_profile.name }
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd php php-mysqlnd
    systemctl start httpd
    systemctl enable httpd
    aws s3 cp s3://${var.s3_bucket_name}/cloudcard/ /var/www/html/ --recursive
    systemctl restart httpd
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags           = { Name = "${var.project_name}-Instance" }
  }
}

# ================= Application Load Balancer =================
resource "aws_lb" "app" {
  name               = "${var.project_name}-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public2.id]
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check { path = "/" }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ================= Auto Scaling Group =================
resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-ASG"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 4
  vpc_zone_identifier = [aws_subnet.private_app.id]
  target_group_arns   = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-Instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu_scaling" {
  name                   = "cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type             = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
