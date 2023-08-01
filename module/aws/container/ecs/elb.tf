locals {
  traffics = [for traffic in var.traffics : {
    listener = {
      protocol = traffic.listener.protocol
      port = coalesce(
        traffic.listener.port,
        traffic.listener.protocol == "http" ? 80 : null,
        traffic.listener.protocol == "https" ? 443 : null,
      )
      protocol_version = traffic.listener.protocol_version
    }
    target = {
      protocol         = traffic.target.protocol
      port             = traffic.target.port
      protocol_version = traffic.target.protocol_version
      health_check_path = coalesce(
        traffic.target.health_check_path,
        "/",
      )
    }
    base = traffic.base
  }]
}

# -----------------
#     ACM
# -----------------
data "aws_route53_zone" "current" {
  for_each = {
    for name in flatten([
      for traffic in local.traffics : [
        for zone in try(var.route53.zones, []) : zone.name
      ] if traffic.listener.protocol == "https"
    ]) : name => {}
  }

  name         = each.key
  private_zone = false
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "4.3.2"

  for_each = {
    for name in flatten([
      for traffic in local.traffics : [
        for zone in try(var.route53.zones, []) : zone.name
      ] if traffic.protocol == "https"
    ]) : name => {}
  }

  create_certificate     = true
  create_route53_records = true

  key_algorithm     = "RSA_2048"
  validation_method = "DNS"

  domain_name = "${var.route53.record.subdomain_name}.${each.key}"
  zone_id     = data.aws_route53_zone.current[each.key].zone_id

  subject_alternative_names = [for prefix in distinct(compact(var.route53.record.prefixes)) : "${prefix}.${var.route53.record.subdomain_name}.${each.key}"]

  wait_for_validation = true
  validation_timeout  = "15m"

  tags = var.tags
}

# -----------------
#     Route53
# -----------------
// ecs service discovery is alternative to route53
module "route53_records" {
  source = "../../../../module/aws/network/route53/record"

  for_each = { for zone in coalesce(try(var.route53.zones, []), []) : zone.name => {} }

  zone_name = each.key
  record = {
    subdomain_name = var.route53.record.subdomain_name
    prefixes       = var.route53.record.prefixes
    type           = "A"
    alias = {
      name    = "dualstack.${module.elb.lb_dns_name}"
      zone_id = module.elb.lb_zone_id
    }
  }

  depends_on = [module.elb]
}

# Cognito for authentication: https://github.com/terraform-aws-modules/terraform-aws-alb/blob/master/examples/complete-alb/main.tf
module "elb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "8.6.0"

  name = var.name

  load_balancer_type = "application"

  vpc_id          = var.vpc.id
  subnets         = local.subnets
  security_groups = [module.elb_sg.security_group_id]

  http_tcp_listeners = [
    for traffic in local.traffics : {
      port               = traffic.listener.port
      protocol           = try(var.protocols[traffic.listener.protocol], "TCP")
      target_group_index = 0
    } if traffic.listener.protocol == "http"
  ]

  https_listeners = [
    for traffic in local.traffics : {
      port               = traffic.listener.port
      protocol           = try(var.protocols[traffic.listener.protocol], "TCP")
      certificate_arn    = module.acm[var.route53.record.subdomain_name].acm_certificate_arn
      target_group_index = 0
    } if traffic.listener.protocol == "https" && var.route53 != null
  ]

  // forward listener to target
  // https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html#target-group-protocol-version
  target_groups = [for traffic in local.traffics : {
    name             = var.name
    backend_protocol = try(var.protocols[traffic.target.protocol], "TCP")
    backend_port     = traffic.target.port
    target_type      = var.service.deployment_type == "fargate" ? "ip" : "instance" # "ip" for awsvpc network, instance for host or bridge
    health_check = {
      enabled             = true
      interval            = 15 // seconds before new request
      path                = traffic.target.health_check_path
      port                = var.service.deployment_type == "fargate" ? traffic.target.port : null // traffic port by default
      healthy_threshold   = 3                                                                     // consecutive health check failures before healthy
      unhealthy_threshold = 3                                                                     // consecutive health check failures before unhealthy
      timeout             = 5                                                                     // seconds for timeout of request
      protocol            = try(var.protocols[traffic.target.protocol], "TCP")
      matcher             = "200-299"
    }
    protocol_version = try(var.protocol_versions[traffic.target.protocol_version], null)
    } if traffic.base || length(local.traffics) == 1
  ]

  # Sleep to give time to the ASG not to fail
  load_balancer_create_timeout = "5m"
  load_balancer_update_timeout = "5m"

  tags = var.tags
}

module "elb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.0.0"

  name        = "${var.name}-sg-elb"
  description = "Security group for ALB within VPC"
  vpc_id      = var.vpc.id

  ingress_with_cidr_blocks = [
    for traffic in local.traffics : {
      from_port   = traffic.listener.port
      to_port     = traffic.listener.port
      protocol    = "tcp"
      description = "Listner port ${traffic.listener.port}"
      cidr_blocks = "0.0.0.0/0"
    } if traffic.listener.protocol == "http" || (traffic.listener.protocol == "https" && var.route53 != null)
  ]
  egress_rules = ["all-all"]
  # egress_cidr_blocks = module.vpc.subnets_cidr_blocks

  tags = var.tags
}
