locals {
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-agent-config.html
  user_data = <<-EOT
    #!/bin/bash
    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER="${var.common_name}"
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
# FIXME: try replace with all individual blocks
module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name = var.common_name

  load_balancer_type = "application"

  vpc_id  = var.vpc_id
  subnets = data.aws_subnets.tier.ids
  # security_groups = concat(var.vpc_security_group_ids, [module.alb_sg.security_group_id])
  security_groups = [module.alb_sg.security_group_id]

  http_tcp_listeners = [
    {
      port               = var.listener_port
      protocol           = var.listener_protocol
      target_group_index = 0
    },
    # {
    # port        = 81
    # protocol    = "HTTP"
    # action_type = "fixed-response"
    # fixed_response = {
    # content_type = "text/plain"
    # message_body = "Load balancer up"
    # status_code  = "200"
    # }
    # },
  ]

  target_groups = [
    {
      name             = "${var.common_name}-tg"
      backend_protocol = var.target_protocol
      backend_port     = var.target_port
      target_type      = "instance"
      # targets = {
      #   ec2 = {
      #     target_id = "i-a1b2c3d4e5f6g7h8i"
      #     port      = var.target_protocol
      #   }
      # }
    }
  ]

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

  # can have more than one capacity provider for spot instances
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cluster-capacity-providers.html
  default_capacity_provider_use_fargate = false
  # autoscaling_capacity_providers = {
  #   on-demand = {
  #     auto_scaling_group_arn = module.asg["on-demand"].autoscaling_group_arn

  #     managed_scaling = {
  #       maximum_scaling_step_size = 5
  #       minimum_scaling_step_size = 1
  #       status                    = "ENABLED"
  #       target_capacity           = 80
  #     }

  #     default_capacity_provider_strategy = {
  #       weight = 100 # TODO cumulative sumn should be 100 with other providers
  #       base   = 1   # min number of task
  #     }
  #   }
  #   # spot = {
  #   #   auto_scaling_group_arn         = module.asg["spot"].autoscaling_group_arn

  #   #   managed_scaling = {
  #   #     maximum_scaling_step_size = 5
  #   #     minimum_scaling_step_size = 1
  #   #     status                    = "ENABLED"
  #   #     target_capacity           = 90
  #   #   }

  #   #   default_capacity_provider_strategy = {
  #   #     weight = 60
  #   #   }
  #   # }
  # }

  tags = var.common_tags
}

resource "aws_ecs_capacity_provider" "this" {
  for_each = {
    on-demand = {
      name = "${var.common_name}-on-demand"
    }
  }

  name = each.value.name

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.this[each.key].arn

    managed_scaling {
      maximum_scaling_step_size = aws_autoscaling_group.this[each.key].max_size
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 60
      instance_warmup_period    = 30
    }
    managed_termination_protection = "DISABLED"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  for_each = {
    on-demand = {
      default_capacity_provider_strategy = {
        base              = 1
        weight            = 100
        capacity_provider = "on-demand",
      }
    }
  }

  cluster_name = module.ecs.cluster_name

  capacity_providers = [aws_ecs_capacity_provider.this[each.key].name]

  default_capacity_provider_strategy {
    base              = each.value.default_capacity_provider_strategy.base
    weight            = each.value.default_capacity_provider_strategy.weight
    capacity_provider = aws_ecs_capacity_provider.this[each.key].name
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/${var.common_name}"
  retention_in_days = var.ecs_logs_retention_in_days

  tags = var.common_tags
}

# ECS Service

# data "aws_ecs_task_definition" "service" {
#   task_definition = var.common_name
# }

resource "aws_ecs_service" "this" {
  name    = var.common_name
  cluster = module.ecs.cluster_id

  desired_count           = var.ecs_task_desired_count
  enable_ecs_managed_tags = true

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this["on-demand"].name
    weight            = 100
    base              = 1
  }

  # deployment_maximum_percent         = 100
  # deployment_minimum_healthy_percent = 10

  force_new_deployment = true
  triggers = {
    redeployment = timestamp()
  }

  # # Use github for task deployment
  # deployment_controller {
  #   type = "EXTERNAL"
  # # }

  load_balancer {
    target_group_arn = module.alb.target_group_arns[0] // works only for one container
    container_name   = var.common_name
    container_port   = var.target_port
  }

  # task_definition = data.aws_ecs_task_definition.service.arn
  task_definition = var.task_definition_arn

  # Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

# ASG
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

# # https://github.com/terraform-aws-modules/terraform-aws-autoscaling/blob/master/examples/complete/main.tf
# module "asg" {
#   source = "terraform-aws-modules/autoscaling/aws"

#   for_each = {
#     on-demand = {
#       instance_type           = var.instance_type_on_demand
#       min_size                = var.min_size_on_demand
#       max_size                = var.max_size_on_demand
#       desired_capacity        = var.desired_capacity_on_demand
#       instance_market_options = {}
#     }
#     # spot = {
#     #   instance_type    = var.instance_type_spot
#     #   min_size         = var.min_size_spot
#     #   max_size         = var.max_size_spot
#     #   desired_capacity = var.desired_capacity_spot
#     #   instance_market_options = {
#     #     market_type = "spot"
#     #     spot_options = {
#     #       block_duration_minutes = 60
#     #     }
#     #   }
#     # }
#   }

#   # key_name = null
#   instance_type           = each.value.instance_type
#   min_size                = each.value.min_size
#   max_size                = each.value.max_size
#   desired_capacity        = each.value.desired_capacity
#   instance_market_options = each.value.instance_market_options

#   use_name_prefix = false
#   name            = "${var.common_name}-${each.key}"
#   image_id                  = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
#   # image_id                  = "ami-09d3b3274b6c5d4aa" # TODO:
#   wait_for_capacity_timeout = 0
#   ebs_optimized             = true
#   enable_monitoring         = true

#   launch_template_name        = var.common_name
#   launch_template_description = "${var.common_name} asg launch template"
#   update_default_version      = true

#   create_iam_instance_profile = true
#   iam_role_name               = var.common_name
#   iam_role_path               = "/ec2/"
#   iam_role_description        = "ASG role for ${var.common_name}"
#   iam_role_policies = {
#     AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
#     AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
#   }
#   iam_role_tags = {
#     CustomIamRole = "Yes"
#   }

#   vpc_zone_identifier     = data.aws_subnets.tier.ids
#   health_check_type       = "EC2"
#   target_group_arns       = module.alb.target_group_arns
#   security_groups         = [module.autoscaling_sg.security_group_id]
#   service_linked_role_arn = aws_iam_service_linked_role.autoscaling.arn
#   user_data               = base64encode(var.user_data)
#   maintenance_options = {
#     auto_recovery = "default"
#   }

#   # cpu_options = {
#   #   core_count       = 1
#   #   threads_per_core = 1
#   # }
#   capacity_reservation_specification = {
#     capacity_reservation_preference = "open"
#   }
#   credit_specification = {
#     cpu_credits = "standard"
#   }

#   block_device_mappings = [
#     {
#       # Root volume
#       device_name = "/dev/xvda"
#       no_device   = 0
#       ebs = {
#         delete_on_termination = true
#         encrypted             = true
#         # TODO: variable
#         volume_size = 30 # SSD, >= 30 GiB, contains the image used to boot the instance
#         volume_type = "gp3"
#       }
#     }
#   ]

#   instance_refresh = {
#     strategy = "Rolling"
#     preferences = {
#       checkpoint_delay       = 600
#       checkpoint_percentages = [35, 70, 100]
#       instance_warmup        = 300
#       min_healthy_percentage = 50
#     }
#     triggers = ["tag"]
#   }

#   # initial_lifecycle_hooks = [
#   #   {
#   #     name                 = "StartupLifeCycleHook"
#   #     default_result       = "CONTINUE"
#   #     heartbeat_timeout    = 60
#   #     lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
#   #     notification_metadata = jsonencode({
#   #       "event"         = "launch",
#   #       "timestamp"     = timestamp(),
#   #       "auto_scaling"  = var.common_name,
#   #       "group"         = each.key,
#   #       "instance_type" = each.value.instance_type
#   #     })
#   #   },
#   #   {
#   #     name                 = "TerminationLifeCycleHook"
#   #     default_result       = "CONTINUE"
#   #     heartbeat_timeout    = 180
#   #     lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
#   #     notification_metadata = jsonencode({
#   #       "event"         = "termination",
#   #       "timestamp"     = timestamp(),
#   #       "auto_scaling"  = var.common_name,
#   #       "group"         = each.key,
#   #       "instance_type" = each.value.instance_type
#   #     })
#   #   }
#   # ]

#   scaling_policies = {
#     avg-cpu-policy-greater-than-50 = {
#       policy_type               = "TargetTrackingScaling"
#       estimated_instance_warmup = 1200
#       target_tracking_configuration = {
#         predefined_metric_specification = {
#           predefined_metric_type = "ASGAverageCPUUtilization"
#         }
#         target_value = 50.0
#       }
#     },
#     predictive-scaling = {
#       policy_type = "PredictiveScaling"
#       predictive_scaling_configuration = {
#         mode                         = "ForecastAndScale"
#         scheduling_buffer_time       = 10
#         max_capacity_breach_behavior = "IncreaseMaxCapacity"
#         max_capacity_buffer          = 10
#         metric_specification = {
#           target_value = 32
#           predefined_scaling_metric_specification = {
#             predefined_metric_type = "ASGAverageCPUUtilization"
#             resource_label         = "testLabel"
#           }
#           predefined_load_metric_specification = {
#             predefined_metric_type = "ASGTotalCPUUtilization"
#             resource_label         = "testLabel"
#           }
#         }
#       }
#     }
#     request-count-per-target = {
#       policy_type               = "TargetTrackingScaling"
#       estimated_instance_warmup = 120
#       target_tracking_configuration = {
#         predefined_metric_specification = {
#           predefined_metric_type = "ALBRequestCountPerTarget"
#           resource_label         = "${module.alb.lb_arn_suffix}/${module.alb.target_group_arn_suffixes[0]}"
#         }
#         target_value = 800
#       }
#     }
#   }

#   tag_specifications = [
#     {
#       resource_type = "instance"
#       tags          = merge(var.common_tags, { Name = "${var.common_name}-instance" })
#     },
#     {
#       resource_type = "volume"
#       tags          = merge(var.common_tags, { Name = "${var.common_name}-volume" })
#     },
#     {
#       resource_type = "spot-instances-request"
#       tags          = merge(var.common_tags, { Name = "${var.common_name}-spot-instance-request" })
#     }
#   ]

#   autoscaling_group_tags = {
#     AmazonECSManaged = true
#   }
#   tags = var.common_tags
# }

# resource "aws_iam_service_linked_role" "autoscaling" {
#   aws_service_name = "autoscaling.amazonaws.com"
#   description      = "A service linked role for autoscaling"
#   custom_suffix    = var.common_name

#   # Sometimes good sleep is required to have some IAM resources created before they can be used
#   provisioner "local-exec" {
#     command = "sleep 10"
#   }
# }

module "autoscaling_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.common_name}-sg-as"
  description = "Autoscaling group security group"
  vpc_id      = var.vpc_id

  computed_ingress_with_source_security_group_id = [
    {
      # rule                     = "http-8080-tcp"
      rule                     = "all-all"
      source_security_group_id = module.alb_sg.security_group_id
      # FIXME: try all sources
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

  egress_rules = ["all-all"]

  tags = var.common_tags
}

data "aws_iam_policy_document" "ecs_agent" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_agent" {
  name               = "${var.common_name}-ecs-agent"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
}


resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_agent" {
  name = "${var.common_name}-ecs-agent"
  role = aws_iam_role.ecs_agent.name
}

resource "aws_launch_configuration" "ecs_launch_config" {
  for_each = {
    on-demand = {
      instance_type = var.instance_type_on_demand
    }
    # spot = {
    #   instance_type    = var.instance_type_spot
    # }
  }
  instance_type = each.value.instance_type

  # image_id             = "ami-09d3b3274b6c5d4aa" #"ami-094d4d00fd7462815"
  image_id             = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
  name_prefix          = var.common_name
  iam_instance_profile = aws_iam_instance_profile.ecs_agent.name
  security_groups      = [module.autoscaling_sg.security_group_id]
  user_data            = var.user_data

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "this" {
  for_each = {
    on-demand = {
      min_size         = var.min_size_on_demand
      max_size         = var.max_size_on_demand
      desired_capacity = var.desired_capacity_on_demand
    }
    # spot = {
    #   min_size         = var.min_size_spot
    #   max_size         = var.max_size_spot
    #   desired_capacity = var.desired_capacity_spot
    #   instance_market_options = {
    #     market_type = "spot"
    #     spot_options = {
    #       block_duration_minutes = 60
    #     }
    #   }
    # }
  }

  min_size         = each.value.min_size
  max_size         = each.value.max_size
  desired_capacity = each.value.desired_capacity

  name = "${var.common_name}-${each.key}"
  # image_id                  = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]

  vpc_zone_identifier  = data.aws_subnets.tier.ids
  launch_configuration = aws_launch_configuration.ecs_launch_config[each.key].name
  capacity_rebalance   = true

  health_check_grace_period = 300
  health_check_type         = "EC2"

  instance_refresh {
    strategy = "Rolling"
  }
}

resource "aws_autoscaling_attachment" "ecs" {
  for_each = {
    on-demand = {},
  }
  autoscaling_group_name = aws_autoscaling_group.this[each.key].id
  alb_target_group_arn   = module.alb.target_group_arns[0] # works only with one tg
}
