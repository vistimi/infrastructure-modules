# Cognito for authentication: https://github.com/terraform-aws-modules/terraform-aws-alb/blob/master/examples/complete-alb/main.tf
module "elb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "8.6.0"

  name = var.common_name

  load_balancer_type = "application"

  vpc_id          = var.vpc.id
  subnets         = local.subnets
  security_groups = [module.elb_sg.security_group_id]

  http_tcp_listeners = [
    for index, listener in var.traffic.listeners : {
      port               = listener.port
      protocol           = try(var.protocols[listener.protocol], "TCP")
      target_group_index = index
    }
    if listener.protocol == "http"
  ]

  https_listeners = [
    for index, listener in var.traffic.listeners : {
      port     = listener.port
      protocol = try(var.protocols[listener.protocol], "TCP")
      # certificate_arn    = "arn:${local.partition}:iam::123456789012:server-certificate/test_cert-123456789012"
      target_group_index = index
    }
    if listener.protocol == "https"
  ]

  // forward listener to target
  // https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html#target-group-protocol-version
  target_groups = [
    for index, target in var.traffic.targets :
    {
      name             = var.common_name
      backend_protocol = try(var.protocols[target.protocol], "TCP")
      backend_port     = target.port
      target_type      = var.service.use_fargate ? "ip" : "instance" # "ip" for awsvpc network, instance for host or bridge
      health_check = {
        enabled             = true
        interval            = 15 // seconds before new request
        path                = target.health_check_path
        port                = var.service.use_fargate ? target.port : null // traffic port by default
        healthy_threshold   = 3                                            // consecutive health check failures before healthy
        unhealthy_threshold = 3                                            // consecutive health check failures before unhealthy
        timeout             = 5                                            // seconds for timeout of request
        protocol            = try(var.protocols[target.protocol], "TCP")
        matcher             = "200-299"
      }
      protocol_version = try(var.protocol_versions[target.protocol_version], null)
    }
  ]

  # Sleep to give time to the ASG not to fail
  load_balancer_create_timeout = "5m"
  load_balancer_update_timeout = "5m"

  tags = var.common_tags
}

module "elb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.0.0"

  name        = "${var.common_name}-sg-elb"
  description = "Security group for ALB within VPC"
  vpc_id      = var.vpc.id

  ingress_with_cidr_blocks = [
    for listener in var.traffic.listeners : {
      from_port   = listener.port
      to_port     = listener.port
      protocol    = "tcp"
      description = "Listner port ${listener.port}"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_rules = ["all-all"]
  # egress_cidr_blocks = module.vpc.subnets_cidr_blocks

  tags = var.common_tags
}
