locals {
  on_demand = "on-demand"
  spot      = "spot"

  capacity_on_demand = "${var.common_name}-${local.on_demand}"
  capacity_spot      = "${var.common_name}-${local.spot}"
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
# https://github.com/terraform-aws-modules/terraform-aws-alb/blob/master/examples/complete-alb/main.tf
# Cognito for authentication
module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name = var.common_name

  load_balancer_type = "application"

  vpc_id          = var.vpc_id
  subnets         = data.aws_subnets.tier.ids
  security_groups = [module.alb_sg.security_group_id]

  http_tcp_listeners = [
    {
      port               = var.listener_port
      protocol           = var.listener_protocol
      target_group_index = 0
    },
  ]

  target_groups = [
    {
      name             = var.common_name
      backend_protocol = var.target_protocol
      backend_port     = var.target_port
      target_type      = "instance"
      health_check = {
        enabled             = true
        interval            = 30
        path                = var.health_check_path
        port                = var.target_port
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 5
        protocol            = var.target_protocol
        matcher             = "200-399"
      }
      tags = var.common_tags
    }
  ]

  # Sleep to give time to the ASG not to fail
  load_balancer_create_timeout = "5m"
  load_balancer_update_timeout = "5m"

  tags = var.common_tags
}

module "alb_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.common_name}-sg-alb"
  description = "Security group for ALB within VPC"
  vpc_id      = var.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp"]
  egress_rules        = ["all-all"]

  tags = var.common_tags
}

# ECS cluster
module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = var.common_name
  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs.name
      }
    }
  }
  default_capacity_provider_use_fargate = false

  tags = var.common_tags
}

resource "aws_ecs_capacity_provider" "this" {
  for_each = {
    on-demand = {
      key_name                  = local.on_demand
      name                      = local.capacity_on_demand
      maximum_scaling_step_size = var.maximum_scaling_step_size_on_demand
      minimum_scaling_step_size = var.minimum_scaling_step_size_on_demand
    },
    spot = {
      key_name                  = local.spot
      name                      = local.capacity_spot
      maximum_scaling_step_size = var.maximum_scaling_step_size_spot
      minimum_scaling_step_size = var.minimum_scaling_step_size_spot
    }
  }

  name = each.value.name

  auto_scaling_group_provider {
    auto_scaling_group_arn = module.asg[each.value.key_name].autoscaling_group_arn

    managed_scaling {
      maximum_scaling_step_size = each.value.maximum_scaling_step_size
      minimum_scaling_step_size = each.value.minimum_scaling_step_size
      status                    = "ENABLED"
      target_capacity           = var.target_capacity_cpu # utilization for the capacity provider
      # instance_warmup_period    = 300
    }
    managed_termination_protection = "DISABLED"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = module.ecs.cluster_name
  capacity_providers = [aws_ecs_capacity_provider.this[local.on_demand].name, aws_ecs_capacity_provider.this[local.spot].name]

  default_capacity_provider_strategy {
    base              = var.capacity_provider_base
    weight            = var.capacity_provider_weight_spot
    capacity_provider = aws_ecs_capacity_provider.this[local.spot].name
  }

  default_capacity_provider_strategy {
    base              = null
    weight            = var.capacity_provider_weight_on_demand
    capacity_provider = aws_ecs_capacity_provider.this[local.on_demand].name
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/${var.common_name}"
  retention_in_days = var.ecs_logs_retention_in_days

  tags = var.common_tags
}

# ECS Service
resource "aws_ecs_service" "this" {
  name    = var.common_name
  cluster = module.ecs.cluster_id

  desired_count           = var.ecs_task_desired_count
  enable_ecs_managed_tags = true

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this[local.spot].name
    base              = var.capacity_provider_base
    weight            = var.capacity_provider_weight_spot
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this[local.on_demand].name
    base              = null
    weight            = var.capacity_provider_weight_on_demand
  }

  force_new_deployment = true
  triggers = {
    redeployment = timestamp()
  }

  load_balancer {
    target_group_arn = module.alb.target_group_arns[0] // works only for one container
    container_name   = var.common_name
    container_port   = var.target_port
  }

  task_definition = var.task_definition_arn

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

# ASG
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  for_each = {
    on-demand = {
      name = var.ami_ssm_name[var.ami_ssm_architecture_on_demand]
    }
    spot = {
      name = var.ami_ssm_name[var.ami_ssm_architecture_spot]
    }
  }
}

# https://github.com/terraform-aws-modules/terraform-aws-autoscaling/blob/master/examples/complete/main.tf
module "asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  for_each = {
    on-demand = {
      key_name                = local.on_demand
      instance_type           = var.instance_type_on_demand
      min_size                = var.min_size_on_demand
      max_size                = var.max_size_on_demand
      desired_capacity        = var.desired_capacity_on_demand
      image_id                = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami["on-demand"].value)["image_id"]
      instance_market_options = {}
      tag_specifications = [
        {
          resource_type = "instance"
          tags          = merge(var.common_tags, { Name = "${var.common_name}-instance" })
        }
      ]
    }
    spot = {
      key_name         = local.spot
      instance_type    = var.instance_type_spot
      min_size         = var.min_size_spot
      max_size         = var.max_size_spot
      desired_capacity = var.desired_capacity_spot
      image_id         = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami["spot"].value)["image_id"]
      instance_market_options = {
        market_type = "spot"
      }
      tag_specifications = [
        {
          resource_type = "instance"
          tags          = merge(var.common_tags, { Name = "${var.common_name}-instance" })
        },
        {
          resource_type = "spot-instances-request"
          tags          = merge(var.common_tags, { Name = "${var.common_name}-spot-instance-request" })
        }
      ]
    }
  }

  instance_type           = each.value.instance_type
  min_size                = each.value.min_size
  max_size                = each.value.max_size
  desired_capacity        = each.value.desired_capacity
  instance_market_options = each.value.instance_market_options
  image_id                = each.value.image_id

  use_name_prefix = false
  name            = "${var.common_name}-${each.value.key_name}"
  # wait_for_capacity_timeout = 0
  enable_monitoring = true
  enabled_metrics = [
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTotalInstances"
  ]

  create_launch_template      = true
  launch_template_name        = var.common_name
  launch_template_description = "${var.common_name} asg launch template"
  update_default_version      = true
  ebs_optimized               = false # optimized ami does not support ebs_optimized
  # key_name = null

  create_iam_instance_profile = true
  iam_role_name               = var.common_name
  iam_role_path               = "/ec2/"
  iam_role_description        = "ASG role for ${var.common_name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    # AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  iam_role_tags = {}

  vpc_zone_identifier     = data.aws_subnets.tier.ids
  health_check_type       = "EC2"
  target_group_arns       = module.alb.target_group_arns
  security_groups         = [module.autoscaling_sg.security_group_id]
  service_linked_role_arn = aws_iam_service_linked_role.autoscaling.arn
  user_data               = base64encode(var.user_data)
  # maintenance_options = {
  #   auto_recovery = "default"
  # }

  # cpu_options = {
  #   core_count       = 1
  #   threads_per_core = 1
  # }
  # capacity_reservation_specification = {
  #   capacity_reservation_preference = "open"
  # }
  # credit_specification = {
  #   cpu_credits = "standard"
  # }

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        # TODO: variable
        volume_size = 30 # SSD, >= 30 GiB, contains the image used to boot the instance
        volume_type = "gp3"
      }
    }
  ]

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

  initial_lifecycle_hooks = [
    {
      name                 = "StartupLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 60
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
      notification_metadata = jsonencode({
        "event"         = "launch",
        "timestamp"     = timestamp(),
        "auto_scaling"  = var.common_name,
        "group"         = each.value.key_name,
        "instance_type" = each.value.instance_type
      })
      notification_target_arn = null
      role_arn                = null
    },
    {
      name                 = "TerminationLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 180
      lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
      notification_metadata = jsonencode({
        "event"         = "termination",
        "timestamp"     = timestamp(),
        "auto_scaling"  = var.common_name,
        "group"         = each.key,
        "instance_type" = each.value.instance_type
      })
      notification_target_arn = null
      role_arn                = null
    }
  ]

  create_schedule = false
  schedules       = {}

  scaling_policies = {
    # # scale based CPU usage
    avg-cpu-policy-greater-than-target = {
      policy_type               = "TargetTrackingScaling"
      estimated_instance_warmup = 1200
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
          # resource_label         = "MyLabel"  # should not be precised with ASGAverageCPUUtilization
        }
        target_value = var.target_capacity_cpu
      }
    },
    # # scale based on previous traffic
    # predictive-scaling = {
    #   policy_type = "PredictiveScaling"
    #   predictive_scaling_configuration = {
    #     mode                         = "ForecastAndScale"
    #     scheduling_buffer_time       = 10
    #     max_capacity_breach_behavior = "IncreaseMaxCapacity"
    #     max_capacity_buffer          = 10
    #     metric_specification = {
    #       target_value = 32
    #       predefined_scaling_metric_specification = {
    #         predefined_metric_type = "ASGAverageCPUUtilization"
    #         resource_label         = "testLabel"
    #       }
    #       predefined_load_metric_specification = {
    #         predefined_metric_type = "ASGTotalCPUUtilization"
    #         resource_label         = "testLabel"
    #       }
    #     }
    #   }
    # },
    # # scale based on ALB requests
    # request-count-per-target = {
    #   policy_type               = "TargetTrackingScaling"
    #   estimated_instance_warmup = 120
    #   target_tracking_configuration = {
    #     predefined_metric_specification = {
    #       predefined_metric_type = "ALBRequestCountPerTarget"
    #       resource_label         = "${module.alb.lb_arn_suffix}/${module.alb.target_group_arn_suffixes[0]}"
    #     }
    #     target_value = 800
    #   }
    # },
  }

  tag_specifications = each.value.tag_specifications

  autoscaling_group_tags = {}
  tags                   = var.common_tags
}

resource "aws_iam_service_linked_role" "autoscaling" {
  aws_service_name = "autoscaling.amazonaws.com"
  description      = "A service linked role for autoscaling"
  custom_suffix    = var.common_name

  # Sometimes good sleep is required to have some IAM resources created before they can be used
  provisioner "local-exec" {
    command = "sleep 10"
  }

  tags = var.common_tags
}

module "autoscaling_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.common_name}-sg-as"
  description = "Autoscaling group security group"
  vpc_id      = var.vpc_id

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "all-all"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

  egress_rules = ["all-all"]

  tags = var.common_tags
}
