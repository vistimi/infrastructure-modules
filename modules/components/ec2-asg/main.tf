
locals {
  http_port     = var.elb_port
  any_port      = 0
  any_protocol  = "-1"
  http_protocol = "HTTP"
  tcp_protocol  = "tcp"
  all_ips       = ["0.0.0.0/0"]
}

# AMI
module "ami" {
  source   = "modules/components/ami"
  ami_name = var.ami_name
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-alb"
  tags = merge(var.common_tags, { Name = "${var.cluster_name}-alb-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id

  from_port   = local.http_port
  to_port     = local.http_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id

  from_port   = local.any_port
  to_port     = local.any_port
  protocol    = local.any_protocol
  cidr_blocks = local.all_ips
}

# ALB creation
resource "aws_lb" "alb" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
  tags = merge(var.common_tags, { Name = "${var.cluster_name}-alb" })

  lifecycle {
    create_before_destroy = true
  }
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = local.http_port
  protocol          = local.http_protocol

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ALB target
resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 Security Group

resource "aws_security_group" "instance" {
  name = var.instance_security_group_name

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = local.tcp_protocol
    cidr_blocks = local.all_ips
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "ec2_launch_config" {
  image_id        = module.ami.id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.instance.id]
  associate_public_ip_address = var.public
  tags = merge(var.common_tags, { Name = "${var.cluster_name}-ec2" })

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 ASG
resource "aws_autoscaling_group" "asg" {
  launch_configuration = aws_launch_configuration.ec2_launch_config.name
  vpc_zone_identifier  = var.subnets_ids
  monitoring=true
  associate_public_ip_address = var.public
  tags = merge(var.common_tags, { Name = "${var.cluster_name}-asg" })

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = var.min_size
  max_size = var.max_size

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }

  lifecycle {
    create_before_destroy = true
  }
}
