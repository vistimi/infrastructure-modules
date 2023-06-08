#------------------------
#     EC2 autoscaler
#------------------------
# https://github.com/terraform-aws-modules/terraform-aws-autoscaling/blob/master/examples/complete/main.tf
module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "6.10.0"

  for_each = {
    for key, value in var.autoscaling_group :
    key => {
      name             = "${var.common_name}-${key}"
      min_size         = value.min_size
      desired_capacity = value.desired_size
      max_size         = value.max_size
      instance_market_options = value.use_spot ? {
        # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#market-options
        market_type = "spot"
        # spot_options = {
        #   block_duration_minutes = 60
        # }
      } : {}
      tag_specifications = value.use_spot ? [{
        resource_type = "spot-instances-request"
        tags          = merge(var.common_tags, { Name = "${var.common_name}-spot-instance-request" })
      }] : []
    }
    if !var.deployment.use_fargate
  }

  name     = each.value.name
  key_name = var.instance.ec2.key_name # to SSH into instance

  # iam configuration
  # iam_instance_profile_arn = aws_iam_instance_profile.ssm.arn // FIXME: try using ssm role
  create_iam_instance_profile = true
  # iam_instance_profile_arn    = aws_iam_instance_profile.ecs_agent.arn
  iam_role_name        = "${var.common_name}-asg"
  iam_role_path        = "/ec2/"
  iam_role_description = "ASG role for ${var.common_name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:${local.partition}:iam::${local.partition}:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    AmazonSSMManagedInstanceCore        = "arn:${local.partition}:iam::${local.partition}:policy/AmazonSSMManagedInstanceCore"
    Custom                              = aws_iam_policy.ecs_agent.arn,
    AmazonEC2FullAccess                 = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
    # Env                                 = aws_iam_policy.bucket_env.arn
    AmazonECS_FullAccess = "arn:aws:iam::aws:policy/AmazonECS_FullAccess" # FIXME: remove
  }
  iam_role_tags = var.common_tags


  # launch template configuration
  tag_specifications = concat(each.value.tag_specifications, [{
    resource_type = "instance"
    tags          = merge(var.common_tags, { Name = "${var.common_name}-instance" })
  }])
  instance_market_options     = each.value.instance_market_options
  instance_type               = var.instance.ec2.instance_type
  image_id                    = local.image_id
  create_launch_template      = true
  launch_template_name        = var.common_name
  launch_template_description = "${var.common_name} asg launch template"
  update_default_version      = true
  ebs_optimized               = false # optimized ami does not support ebs_optimized
  user_data                   = base64encode(var.user_data)
  # metadata_options = {
  # # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#metadata-options
  #   http_endpoint               = "enabled"
  #   http_tokens                 = "required"
  #   http_put_response_hop_limit = 32
  # }
  use_name_prefix = false
  # wait_for_capacity_timeout = 0
  enable_monitoring = true
  enabled_metrics = [
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTotalInstances"
  ]
  # maintenance_options = { // new
  # auto_recovery = "default"
  # }
  # key_name = null

  network_interfaces = [
    // https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#network-interfaces
    {
      associate_public_ip_address = true
      delete_on_termination       = true
      description                 = "eth0"
      device_index                = 0
      security_groups             = [module.autoscaling_sg.security_group_id]
    }
  ]
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
  # block_device_mappings = [
  #   {
  #     # Root volume
  #     device_name = "/dev/xvda"
  #     no_device   = 0
  #     ebs = {
  #       delete_on_termination = true
  #       encrypted             = false
  #       volume_size           = 30
  #       volume_type           = "gp3"
  #     }
  #   }
  # ]

  # asg configuration
  ignore_desired_capacity_changes = false
  min_size                        = each.value.min_size
  max_size                        = each.value.max_size
  desired_capacity                = each.value.desired_capacity
  vpc_zone_identifier             = local.subnets
  health_check_type               = "EC2"
  target_group_arns               = module.alb.target_group_arns
  security_groups                 = [module.autoscaling_sg.security_group_id]
  service_linked_role_arn         = aws_iam_service_linked_role.autoscaling.arn
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

  # initial_lifecycle_hooks = [
  #   {
  #     name                 = "StartupLifeCycleHook"
  #     default_result       = "CONTINUE"
  #     heartbeat_timeout    = 60
  #     lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  #     notification_metadata = jsonencode({
  #       "event"         = "launch",
  #       "timestamp"     = timestamp(),
  #       "auto_scaling"  = var.common_name,
  #       "group"         = each.key,
  #       "instance_type" = var.instance.ec2.instance_type
  #     })
  #     notification_target_arn = null
  #     role_arn                = aws_iam_policy.ecs_task_logs.arn
  #   },
  #   {
  #     name                 = "TerminationLifeCycleHook"
  #     default_result       = "CONTINUE"
  #     heartbeat_timeout    = 180
  #     lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
  #     notification_metadata = jsonencode({
  #       "event"         = "termination",
  #       "timestamp"     = timestamp(),
  #       "auto_scaling"  = var.common_name,
  #       "group"         = each.key,
  #       "instance_type" = var.instance.ec2.instance_type
  #     })
  #     notification_target_arn = null
  #     role_arn                = aws_iam_policy.ecs_task_logs.arn
  #   }
  # ]

  # schedule configuration
  create_schedule = false
  schedules       = {}

  # scaling configuration
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
        target_value = 70 // TODO: var.target_capacity_cpu
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

  autoscaling_group_tags = {}
  tags                   = var.common_tags

  depends_on = [aws_iam_service_linked_role.autoscaling]
}

resource "aws_iam_service_linked_role" "autoscaling" {
  aws_service_name = "autoscaling.${local.dns_suffix}"
  description      = "A service linked role for autoscaling"
  custom_suffix    = var.common_name

  # Sometimes good sleep is required to have some IAM resources created before they can be used
  provisioner "local-exec" {
    command = "sleep 10"
  }

  tags = var.common_tags
}

module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.0.0"

  name        = "${var.common_name}-sg-asg"
  description = "Autoscaling group security group" # "Security group with HTTP port open for everyone, and HTTPS open just for the default security group"
  vpc_id      = var.vpc.id
  // FIXME: add again
  // only accept incoming traffic from load balancer 
  computed_ingress_with_source_security_group_id = [
    {
      rule = "all-all"
      # rule                     = "https-443-tcp"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1
  ingress_cidr_blocks                                      = ["0.0.0.0/0"]
  # ingress_rules                                            = ["all-all"]
  ingress_with_cidr_blocks = var.instance.ec2.key_name != null ? [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH"
      cidr_blocks = "0.0.0.0/0"
    },
  ] : []
  egress_rules = ["all-all"]

  tags = var.common_tags
}

resource "aws_autoscaling_attachment" "ecs" {
  for_each = {
    for key, _ in var.autoscaling_group :
    key => {}
    if !var.deployment.use_fargate
  }
  autoscaling_group_name = module.asg[each.key].autoscaling_group_name
  lb_target_group_arn    = module.alb.target_group_arns[0] # works only with one tg
}

# data "aws_iam_policy_document" "ecs_agent" {
#   statement {
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["ec2.${local.dns_suffix}"]
#     }
#   }
# }

# data "aws_iam_policy" "aws_ec2_container_service_for_ec2_role" {
#   name = "AmazonEC2ContainerServiceforEC2Role"
# }

# data "aws_iam_policy" "aws_ssm_management_instance_core" {
#   name = "AmazonSSMManagedInstanceCore"
# }

# data "aws_iam_policy" "aws_ssm_management_instance_core" {
#   name = "AmazonSSMManagedInstanceCore"
# }

# resource "aws_iam_role" "ecs_agent" {
#   name               = "${var.common_name}-ecs-agent"
#   assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
#   managed_policy_arns = [
#     data.aws_iam_policy.aws_ec2_full_access_policy.arn,
#     data.aws_iam_policy.aws_ec2_container_service_for_ec2_role.arn,
#     data.aws_iam_policy.aws_ssm_management_instance_core.arn,
#     aws_iam_policy.ecr.arn,
#     aws_iam_policy.bucket_env.arn,
#     aws_iam_policy.ecs_task_logs.arn,
#   ]
# }

# data "aws_iam_policy_document" "ecs_agent" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["ec2.amazonaws.com"]
#     }

#     actions = ["sts:AssumeRole"]
#   }
# }

resource "aws_iam_policy" "ecs_agent" {
  name = "${var.common_name}-ecs-agent"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          # // AmazonEC2ContainerServiceforEC2Role for ec2
          # "ec2:DescribeTags",
          # "ecs:CreateCluster",
          # "ecs:DeregisterContainerInstance",
          # "ecs:DiscoverPollEndpoint",
          # "ecs:Poll",
          # "ecs:RegisterContainerInstance",
          # "ecs:StartTelemetrySession",
          # "ecs:UpdateContainerInstancesState",
          # "ecs:Submit*",
          # "ecr:GetAuthorizationToken",
          # "ecr:BatchCheckLayerAvailability",
          # "ecr:GetDownloadUrlForLayer",
          # "ecr:BatchGetImage",
          # "logs:CreateLogStream",
          # "logs:PutLogEvents",
          # # determine who can access Amazon EC2 Auto Scaling
          # "autoscaling:InstanceTypes",
          # "autoscaling:LaunchConfigurationName",
          # "autoscaling:LaunchTemplateVersionSpecified",
          # "autoscaling:LoadBalancerNames",
          # "autoscaling:MaxSize",
          # "autoscaling:MinSize",
          # "autoscaling:ResourceTag/*: *",
          # "autoscaling:TargetGroupARNs",
          # "autoscaling:VPCZoneIdentifiers",
          # # create launch configuration requests
          # "autoscaling:ImageId",
          # "autoscaling:InstanceType",
          # "autoscaling:MetadataHttpEndpoint",
          # "autoscaling:MetadataHttpPutResponseHopLimit",
          # "autoscaling:MetadataHttpTokens",
          # "autoscaling:SpotPrice",
          # # permissions based on the tags
          # "aws:RequestTag/*: *",
          # "aws:ResourceTag/*: *",
          # "aws:TagKeys: [*]",
          "autoscaling:*",
          "ecs:*",
          "ec2:*",
          "ecr:*",
          "s3:*"

          # "ecs:DeregisterContainerInstance",
          # "ecs:DiscoverPollEndpoint",
          # "ecs:Poll",
          # "ecs:RegisterContainerInstance",
          # "ecs:StartTelemetrySession",
          # "ecs:Submit*",
          # "ecr:GetAuthorizationToken",
          # "ecr:BatchCheckLayerAvailability",
          # "ecr:GetDownloadUrlForLayer",
          # "ecr:BatchGetImage",
          # "logs:CreateLogStream",
          # "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*",
      },
    ]
  })
}


# group notification
# resource "aws_autoscaling_notification" "webserver_asg_notifications" {
#   group_names = [
#     aws_autoscaling_group.webserver_asg.name,
#   ]
#   notifications = [
#     "autoscaling:EC2_INSTANCE_LAUNCH",
#     "autoscaling:EC2_INSTANCE_TERMINATE",
#     "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
#     "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
#   ]
#   topic_arn = aws_sns_topic.webserver_topic.arn
# }
# resource "aws_sns_topic" "webserver_topic" {
#   name = "webserver_topic"
# }
