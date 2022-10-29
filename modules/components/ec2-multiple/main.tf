
locals {
  http_port     = var.elb_port
  any_port      = 0
  any_protocol  = "-1"
  http_protocol = "HTTP"
  tcp_protocol  = "tcp"
  all_ips       = ["0.0.0.0/0"]

  asg_name = "${var.cluster_name}-asg"
  alb_name = "${var.cluster_name}-alb"
  logs_name = "${var.cluster_name}-logs"
}

module "alb_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "~> 4.16.0"

  name        = "${local.alb_name}-sg"
  description = "Security group for ALB within VPC"
  vpc_id      = var.vpc_id

  ingress_cidr_blocks = var.subnets_ids

  tags = var.common_tags
}

# ALB
module "s3_bucket_for_logs" {
  source = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.4.1"

  bucket = local.logs_name
  acl    = "log-delivery-write"

  # Allow deletion of non-empty bucket
  force_destroy = true

  attach_elb_log_delivery_policy = true  # Required for ALB logs
  attach_lb_log_delivery_policy  = true  # Required for ALB/NLB logs
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.1.2"

  name = local.alb_name

  load_balancer_type = "application"

  vpc_id             = var.vpc_id
  subnets            = var.subnets_ids
  security_groups    = [module.alb_sg.security_group_id]

  access_logs = {
    bucket = local.logs_name
  }

  target_groups = [
    {
      name_prefix      = "pref-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = var.common_tags
}

# ASG
module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "6.5.3"

  # Autoscaling group
  name = local.asg_name

  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  wait_for_capacity_timeout = 0
  health_check_type         = "ELB"
  vpc_zone_identifier       = var.subnets_ids

  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay       = 600
      checkpoint_percentages = [35, 70, 100]
      instance_warmup        = 300
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }

  # Launch template
  launch_template_name        = local.asg_name
  launch_template_description = "${var.cluster_name} asg launch template"
  update_default_version      = true

  image_id          = var.ami_id
  instance_type     = var.instance_type
  ebs_optimized     = true
  enable_monitoring = true

  # IAM role & instance profile
  create_iam_instance_profile = true
  iam_role_name               = local.asg_name
  iam_role_path               = "/ec2/"
  iam_role_description        = "${var.cluster_name} role"
  iam_role_tags = {
    CustomIamRole = "Yes"
  }
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # ALB
  target_group_arns=[moodule.alb.lb_arn]

  # Tags
  tag_specifications = [
    {
      resource_type = "instance"
      tags          = merge(var.common_tags, { Name = "${var.cluster_name}-instance" })
    },
    {
      resource_type = "volume"
      tags          = merge(var.common_tags, { Name = "${var.cluster_name}-volume" })
    },
  ]

  tags = var.common_tags
}

# # AMI
# module "ami" {
#   source   = "../ami"
#   ami_name= var.ami_name
# }

# # ALB Security Group
# resource "aws_security_group" "alb" {
#   name = "${var.cluster_name}-alb"

#   tags = merge(var.common_tags, { Name = "${var.cluster_name}-alb-sg" })

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_security_group_rule" "allow_http_inbound" {
#   type              = "ingress"
#   security_group_id = aws_security_group.alb.id

#   from_port   = local.http_port
#   to_port     = local.http_port
#   protocol    = local.tcp_protocol
#   cidr_blocks = local.all_ips
# }

# resource "aws_security_group_rule" "allow_all_outbound" {
#   type              = "egress"
#   security_group_id = aws_security_group.alb.id

#   from_port   = local.any_port
#   to_port     = local.any_port
#   protocol    = local.any_protocol
#   cidr_blocks = local.all_ips
# }

# # ALB creation
# resource "aws_lb" "alb" {
#   name               = "terraform-asg-example"
#   load_balancer_type = "application"
#   subnets            = data.aws_subnets.default.ids
#   security_groups    = [aws_security_group.alb.id]

#   tags = merge(var.common_tags, { Name = "${var.cluster_name}-alb" })

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # ALB Listener
# resource "aws_lb_listener" "http" {
#   load_balancer_arn = aws_lb.example.arn
#   port              = local.http_port
#   protocol          = local.http_protocol

#   # By default, return a simple 404 page
#   default_action {
#     type = "fixed-response"

#     fixed_response {
#       content_type = "text/plain"
#       message_body = "404: page not found"
#       status_code  = 404
#     }
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # ALB target
# resource "aws_lb_target_group" "asg" {
#   name     = "terraform-asg-example"
#   port     = var.server_port
#   protocol = "HTTP"
#   vpc_id   = var.vpc_id

#   health_check {
#     path                = var.health_check_path
#     protocol            = "HTTP"
#     matcher             = "200"
#     interval            = 15
#     timeout             = 3
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # EC2 Security Group

# resource "aws_security_group" "instance" {
#   name = var.instance_security_group_name

#   ingress {
#     from_port   = var.server_port
#     to_port     = var.server_port
#     protocol    = local.tcp_protocol
#     cidr_blocks = local.all_ips
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_launch_configuration" "ec2_launch_config" {
#   image_id        = module.ami.id
#   instance_type   = var.instance_type
#   security_groups = [aws_security_group.instance.id]
#   associate_public_ip_address = var.public

#   tags = merge(var.common_tags, { Name = "${var.cluster_name}-ec2" })

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # EC2 ASG
# resource "aws_autoscaling_group" "asg" {
#   launch_configuration = aws_launch_configuration.ec2_launch_config.name
#   vpc_zone_identifier  = var.subnets_ids
#   monitoring=true
#   associate_public_ip_address = var.public

#   target_group_arns = [aws_lb_target_group.asg.arn]
#   health_check_type = "ELB"

#   min_size = var.min_size
#   max_size = var.max_size

#   tags = merge(var.common_tags, { Name = "${var.cluster_name}-asg" })

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_lb_listener_rule" "asg" {
#   listener_arn = aws_lb_listener.http.arn
#   priority     = 100

#   condition {
#     path_pattern {
#       values = ["*"]
#     }
#   }

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.asg.arn
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }
