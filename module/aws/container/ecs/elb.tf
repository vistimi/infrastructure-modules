locals {
  listener_protocol = var.traffic.listener_protocol == "http" ? "HTTP" : var.traffic.listener_protocol == "https" ? "HTTPS" : "TCP"
  target_protocol   = var.traffic.target_protocol == "http" ? "HTTP" : var.traffic.target_protocol == "https" ? "HTTPS" : "TCP"
  target_protocol_version = var.traffic.target_protocol_version == "http" ? "HTTP1" : (
    var.traffic.target_protocol_version == "http2" ? "HTTP2" : (
      var.traffic.target_protocol_version == "grpc" ? "GRPC" : null
    )
  )
}

# Cognito for authentication: https://github.com/terraform-aws-modules/terraform-aws-alb/blob/master/examples/complete-alb/main.tf
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "8.6.0"

  name = var.common_name

  load_balancer_type = "application"

  vpc_id          = var.vpc.id
  subnets         = local.subnets
  security_groups = [module.alb_sg.security_group_id] // TODO: add vpc security group

  # access_logs = {
  #   bucket = module.s3_logs_alb.s3_bucket_id
  # }

  http_tcp_listeners = var.traffic.listener_protocol == "http" ? [
    {
      port               = var.traffic.listener_port
      protocol           = local.listener_protocol
      target_group_index = 0
    },
  ] : []

  https_listeners = var.traffic.listener_protocol == "https" ? [
    {
      port     = var.traffic.listener_port
      protocol = local.listener_protocol
      # certificate_arn    = "arn:${local.partition}:iam::123456789012:server-certificate/test_cert-123456789012"
      target_group_index = 0
    }
  ] : []

  // forward listener to target
  // https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html#target-group-protocol-version
  target_groups = [
    {
      name             = var.common_name
      backend_protocol = local.target_protocol
      backend_port     = var.traffic.target_port
      target_type      = var.service.use_fargate ? "ip" : "instance" # "ip" for awsvpc network, instance for host or bridge
      health_check = {
        enabled             = true
        interval            = 15 // seconds before new request
        path                = var.traffic.health_check_path
        port                = var.service.use_fargate ? var.traffic.target_port : null // traffic port by default
        healthy_threshold   = 3                                                        // consecutive health check failures before healthy
        unhealthy_threshold = 3                                                        // consecutive health check failures before unhealthy
        timeout             = 5                                                        // seconds for timeout of request
        protocol            = local.target_protocol
        matcher             = "200-299"
      }
      protocol_version = local.target_protocol_version
    }
  ]

  # Sleep to give time to the ASG not to fail
  load_balancer_create_timeout = "5m"
  load_balancer_update_timeout = "5m"

  tags = var.common_tags
}

module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.0.0"

  name        = "${var.common_name}-sg-alb"
  description = "Security group for ALB within VPC"
  vpc_id      = var.vpc.id

  ingress_with_cidr_blocks = [
    {
      from_port   = var.traffic.listener_port
      to_port     = var.traffic.listener_port
      protocol    = "tcp"
      description = "Listner port"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
  egress_rules = ["all-all"]
  # egress_cidr_blocks = module.vpc.subnets_cidr_blocks

  tags = var.common_tags
}
