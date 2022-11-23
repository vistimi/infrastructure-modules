locals {
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-agent-config.html
  user_data = <<-EOT
    #!/bin/bash
    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER="${var.common_name}-cluster"
    EOF
  EOT
}

data "aws_subnets" "tier" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Tier = var.vpc_tier
  }
}

# ALB
# https://github.com/terraform-aws-modules/terraform-aws-alb/blob/v8.1.2/examples/complete-alb/main.tf
# Cognito for authentication
module "alb" {
  source  = "terraform-aws-modules/alb/aws"

  name = var.common_name

  load_balancer_type = "application"

  vpc_id          = var.vpc_id
  subnets         = data.aws_subnets.public.ids
  security_groups = [module.alb_sg.security_group_id]

  target_groups = [
    {
      name             = var.common_name
      backend_protocol = var.target_protocol
      backend_port     = var.target_port
      target_type      = "instance"
    }
  ]

  http_tcp_listeners = [
    {
      port               = var.listener_port
      protocol           = var.listener_protocol
      target_group_index = 0
    }
  ]

  tags = var.common_tags
}

# Only works for HTTP 80 here
module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws//modules/http-80"

  name        = "${var.common_name}-alb-sg"
  description = "Security group for ALB within VPC"
  vpc_id      = var.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]

  tags = var.common_tags
}

# ECS cluster
module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  common_name = "${var.common_name}-cluster"

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs.name
      }
    }
  }

  # can have more than one capacity provider for spot instances
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cluster-capacity-providers.html
  autoscaling_capacity_providers = {
    on_demand = {
      auto_scaling_group_arn         = module.autoscaling["on_demand"].autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 5
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 80
      }

      default_capacity_provider_strategy = {
        weight = 40
        base   = 1 # min number of task
      }
    }
    spot = {
      auto_scaling_group_arn         = module.autoscaling["spot"].autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 5
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 90
      }

      default_capacity_provider_strategy = {
        weight = 60
      }
    }
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/${var.common_name}"
  retention_in_days = var.ecs_logs_retention_in_days

  tags = var.common_tags
}

# ECS Service
resource "aws_ecs_service" "service" {
  name            = "${var.common_name}-service"
  cluster         = module.ecs.cluster_id

  desired_count           = 1
  enable_ecs_managed_tags = true

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 10

  force_new_deployment = true
  triggers = {
    redeployment = timestamp()
  }

  # Use github for task deployment
  deployment_controller {
    type = "EXTERNAL"
  }
  # task_definition = var.task_definition_arn

  # Optional: Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [task_definition]
  }
}

# ASG
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

# https://github.com/terraform-aws-modules/terraform-aws-autoscaling/blob/v6.5.3/examples/complete/main.tf
module "asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  for_each = {
    on_demand = {
      instance_type    = var.instance_type_on_demand
      min_size         = var.min_size_on_demand
      max_size         = var.max_size_on_demand
      desired_capacity = var.desired_capacity_on_demand
      instance_market_options = {
        market_type = "on_demand"
      }
    }
    spot = {
      instance_type    = var.instance_type_spot
      min_size         = var.min_size_spot
      max_size         = var.max_size_spot
      desired_capacity = var.desired_capacity_spot
      instance_market_options = {
        market_type = "spot"
        spot_options = {
          block_duration_minutes = 30
        }
      }
    }
  }

  name     = "${local.asg_name}-${each.key}"
  image_id = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]

  initial_lifecycle_hooks = [
    {
      name                 = "StartupLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 60
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
      notification_metadata = jsonencode({
        "event"         = "launch",
        "timestamp"     = "${timestamp()}",
        "auto_scaling"  = "${local.asg_name}",
        "group"         = "${each.key}",
        "instance_type" = "each.value.instance_type"
      })
    },
    {
      name                 = "TerminationLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 180
      lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
      notification_metadata = jsonencode({
        "event"         = "termination",
        "timestamp"     = "${timestamp()}",
        "auto_scaling"  = "${local.asg_name}",
        "group"         = "${each.key}",
        "instance_type" = "each.value.instance_type"
      })
    }
  ]

  security_groups = [module.autoscaling_sg.security_group_id]
  user_data       = base64encode(var.user_data)
  maintenance_options = {
    auto_recovery = "default"
  }

  create_iam_instance_profile = true
  iam_role_name               = local.asg_name
  iam_role_description        = "ECS role for ${local.name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  vpc_zone_identifier = data.aws_subnets.tier.ids
  health_check_type   = "ELB"
  target_group_arns   = module.alb.target_group_arns

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

  launch_template_name        = local.asg_name
  launch_template_description = "${var.common_name} asg launch template"
  update_default_version      = true
  ebs_optimized               = true
  enable_monitoring           = true

  tag_specifications = [
    {
      resource_type = "instance"
      tags          = merge(var.common_tags, { Name = "${var.common_name}-instance" })
    },
    {
      resource_type = "volume"
      tags          = merge(var.common_tags, { Name = "${var.common_name}-volume" })
    },
    {
      resource_type = "spot-instances-request"
      tags          = merge(var.common_tags, { Name = "${var.common_name}-spot-instance-request" })
    }
  ]

  autoscaling_group_tags = {
    AmazonECSManaged = true
  }
  tags = var.common_tags
}

# Only works for HTTP 80 here
module "autoscaling_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = local.name
  description = "Autoscaling group security group"
  vpc_id      = var.vpc_id

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.alb_http_sg.security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

  egress_rules = ["all-all"]

  tags = local.tags
}
