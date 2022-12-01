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
module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name = var.common_name

  load_balancer_type = "application"

  vpc_id          = var.vpc_id
  subnets         = data.aws_subnets.tier.ids
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

module "alb_sg" {
  # Only works for HTTP 80 here
  source = "terraform-aws-modules/security-group/aws//modules/http-80"

  name        = "${var.common_name}-alb-sg"
  description = "Security group for ALB within VPC"
  vpc_id      = var.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]

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
  autoscaling_capacity_providers = {
    on-demand = {
      auto_scaling_group_arn         = module.asg["on-demand"].autoscaling_group_arn

      managed_scaling = {
        maximum_scaling_step_size = 5
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 80
      }

      default_capacity_provider_strategy = {
        weight = 100  # TODO cumulative sumn should be 100 with other providers
        base   = 1 # min number of task
      }
    }
    # spot = {
    #   auto_scaling_group_arn         = module.asg["spot"].autoscaling_group_arn

    #   managed_scaling = {
    #     maximum_scaling_step_size = 5
    #     minimum_scaling_step_size = 1
    #     status                    = "ENABLED"
    #     target_capacity           = 90
    #   }

    #   default_capacity_provider_strategy = {
    #     weight = 60
    #   }
    # }
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/${var.common_name}"
  retention_in_days = var.ecs_logs_retention_in_days

  tags = var.common_tags
}

# ECS Service

data "aws_ecs_task_definition" "service" {
  task_definition = var.common_name
}

resource "aws_ecs_service" "service" {
  name    = var.common_name
  cluster = module.ecs.cluster_id

  desired_count           = 1 // TODO: set as variable
  enable_ecs_managed_tags = true

  # deployment_maximum_percent         = 100
  # deployment_minimum_healthy_percent = 10

  force_new_deployment = true
  triggers = {
    redeployment = timestamp()
  }

  load_balancer {
    target_group_arn = module.alb.target_group_arns[0] // works only for one container
    container_name   = var.common_name
    container_port   = var.target_port
  }

  # # Use github for task deployment
  # deployment_controller {
  #   type = "EXTERNAL"
  # }
  task_definition = aws_ecaws_ecs_task_definitionr_image.service.arn

  # Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [task_definition]
  }

    provisioner "local-exec" {
    command = "/bin/bash gh_wf_ecr.sh GH_WF_FILE=$GH_WF_FILE GH_WF_NAME=$GH_WF_NAME GH_ORG=$GH_ORG GH_REPO=$GH_REPO GH_BRANCH=$GH_BRANCH AWS_ACCOUNT_NAME=$AWS_ACCOUNT_NAME AWS_REGION=$AWS_REGION COMMON_NAME=$COMMON_NAME"
    environment = {
      GH_WF_FILE       = var.github_workflow_file_name_env
      GH_WF_NAME       = var.github_workflow_name_env
      GH_ORG           = var.github_organization
      GH_REPO          = var.github_repository
      GH_BRANCH        = var.github_branch
      AWS_ACCOUNT_NAME = var.account_name
      AWS_REGION       = var.account_region
      COMMON_NAME      = var.common_name
    }
  }
}

# ASG
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

# https://github.com/terraform-aws-modules/terraform-aws-autoscaling/blob/master/examples/complete/main.tf
module "asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  for_each = {
    on-demand = {
      instance_type           = var.instance_type_on_demand
      min_size                = var.min_size_on_demand
      max_size                = var.max_size_on_demand
      desired_capacity        = var.desired_capacity_on_demand
      instance_market_options = {}
    }
    # spot = {
    #   instance_type    = var.instance_type_spot
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

  # key_name = null
  instance_type           = each.value.instance_type
  min_size                = each.value.min_size
  max_size                = each.value.max_size
  desired_capacity        = each.value.desired_capacity
  instance_market_options = each.value.instance_market_options

  use_name_prefix           = false
  name                      = "${var.common_name}-${each.key}"
  image_id                  = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
  wait_for_capacity_timeout = 0
  ebs_optimized             = true
  enable_monitoring         = true

  launch_template_name        = var.common_name
  launch_template_description = "${var.common_name} asg launch template"
  update_default_version      = true

  create_iam_instance_profile = true
  iam_role_name               = var.common_name
  iam_role_path               = "/ec2/"
  iam_role_description        = "ASG role for ${var.common_name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  iam_role_tags = {
    CustomIamRole = "Yes"
  }

  vpc_zone_identifier     = data.aws_subnets.tier.ids
  health_check_type       = "EC2"
  target_group_arns       = module.alb.target_group_arns
  security_groups         = [module.autoscaling_sg.security_group_id]
  service_linked_role_arn = aws_iam_service_linked_role.autoscaling.arn
  user_data               = base64encode(var.user_data)
  maintenance_options = {
    auto_recovery = "default"
  }

  # cpu_options = {
  #   core_count       = 1
  #   threads_per_core = 1
  # }
  capacity_reservation_specification = {
    capacity_reservation_preference = "open"
  }
  credit_specification = {
    cpu_credits = "standard"
  }

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        # TODO: variable
        volume_size           = 30  # SSD, >= 30 GiB, contains the image used to boot the instance
        volume_type           = "gp3"
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
        "group"         = each.key,
        "instance_type" = each.value.instance_type
      })
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
    }
  ]

  scaling_policies = {
    avg-cpu-policy-greater-than-50 = {
      policy_type               = "TargetTrackingScaling"
      estimated_instance_warmup = 1200
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = 50.0
      }
    },
    predictive-scaling = {
      policy_type = "PredictiveScaling"
      predictive_scaling_configuration = {
        mode                         = "ForecastAndScale"
        scheduling_buffer_time       = 10
        max_capacity_breach_behavior = "IncreaseMaxCapacity"
        max_capacity_buffer          = 10
        metric_specification = {
          target_value = 32
          predefined_scaling_metric_specification = {
            predefined_metric_type = "ASGAverageCPUUtilization"
            resource_label         = "testLabel"
          }
          predefined_load_metric_specification = {
            predefined_metric_type = "ASGTotalCPUUtilization"
            resource_label         = "testLabel"
          }
        }
      }
    }
    request-count-per-target = {
      policy_type               = "TargetTrackingScaling"
      estimated_instance_warmup = 120
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ALBRequestCountPerTarget"
          resource_label         = "${module.alb.lb_arn_suffix}/${module.alb.target_group_arn_suffixes[0]}"
        }
        target_value = 800
      }
    }
  }

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

module "autoscaling_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.common_name}-sg-as"
  description = "Autoscaling group security group"
  vpc_id      = var.vpc_id

  computed_ingress_with_source_security_group_id = [
    {
      # Only works for HTTP 80 here
      rule                     = "http-80-tcp"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

  egress_rules = ["all-all"]

  tags = var.common_tags
}

resource "aws_iam_service_linked_role" "autoscaling" {
  aws_service_name = "autoscaling.amazonaws.com"
  description      = "A service linked role for autoscaling"
  custom_suffix    = var.common_name

  # Sometimes good sleep is required to have some IAM resources created before they can be used
  provisioner "local-exec" {
    command = "sleep 10"
  }
}

# EC2
# TODO instead of create IAM in ASG
# data "aws_iam_policy_document" "ecs_agent" {
#   statement {
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["ec2.amazonaws.com"]
#     }
#   }
# }

# resource "aws_iam_role" "ecs_agent" {
#   name               = "ecs-agent"
#   assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
# }


# resource "aws_iam_role_policy_attachment" "ecs_agent" {
#   role       = "aws_iam_role.ecs_agent.name"
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
# }

# resource "aws_iam_instance_profile" "ecs_agent" {
#   name = "ecs-agent"
#   role = aws_iam_role.ecs_agent.name
# }
