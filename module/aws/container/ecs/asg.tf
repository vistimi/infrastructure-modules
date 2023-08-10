locals {
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/retrieve-ecs-optimized_AMI.html
  ami_ssm_name = {
    amazon-linux-2-x86_64    = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
    amazon-linux-2-arm_64    = "/aws/service/ecs/optimized-ami/amazon-linux-2/arm64/recommended/image_id"
    amazon-linux-2-gpu       = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended/image_id"
    amazon-linux-2-inf       = "/aws/service/ecs/optimized-ami/amazon-linux-2/inf/recommended/image_id"
    amazon-linux-2023-x86_64 = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
    amazon-linux-2023-arm_64 = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id"
    # amazon-linux-2023-gpu   = "/aws/service/ecs/optimized-ami/amazon-linux-2023/gpu/recommended/image_id"
    amazon-linux-2023-inf = "/aws/service/ecs/optimized-ami/amazon-linux-2023/inf/recommended/image_id"
  }
}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami_id" {
  for_each = {
    for key, value in var.ec2 :
    key => {
      name = local.ami_ssm_name[join("-", ["amazon", value.os, value.os_version, value.architecture])]
    }
    if var.service.deployment_type == "ec2"
  }

  name = each.value.name
}

locals {
  image_ids = {
    for key, value in var.ec2 :
    key => data.aws_ssm_parameter.ecs_optimized_ami_id[key].value if var.service.deployment_type == "ec2"
  }

  # https://github.com/aws/amazon-ecs-agent/blob/master/README.md
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-gpu.html
  # <<- is required compared to << because there should be no identation for EOT and EOF to work properly
  user_data = {
    for key, value in var.ec2 : key => <<-EOT
        #!/bin/bash
        cat <<'EOF' >> /etc/ecs/ecs.config
        ECS_CLUSTER=${var.name}
        ${value.use_spot ? "ECS_ENABLE_SPOT_INSTANCE_DRAINING=true" : ""}
        ECS_ENABLE_TASK_IAM_ROLE=true
        ${value.architecture == "gpu" ? "ECS_ENABLE_GPU_SUPPORT=true" : ""}
        ${value.architecture == "gpu" ? "ECS_NVIDIA_RUNTIME=nvidia" : ""}
        EOF
        ${value.user_data != null ? value.user_data : ""}
      EOT
  }

  weight_total = var.service.deployment_type == "fargate" ? 0 : sum([for key, value in var.ec2 : value.capacity_provider.weight])
}

#------------------------
#     EC2 autoscaler
#------------------------
# https://github.com/terraform-aws-modules/terraform-aws-autoscaling/blob/master/examples/complete/main.tf
module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "6.10.0"

  for_each = {
    for key, value in var.ec2 :
    key => {
      name              = "${var.name}-${key}"
      capacity_provider = value.capacity_provider
      instance_market_options = value.use_spot ? {
        # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#market-options
        market_type = "spot"
        # spot_options = {
        #   block_duration_minutes = 60
        # }
      } : {}
      tag_specifications = value.use_spot ? [{
        resource_type = "spot-instances-request"
        tags          = merge(var.tags, { Name = "${var.name}-spot-instance-request" })
      }] : []
      instance_type    = value.instance_type
      key_name         = value.key_name # to SSH into instance
      instance_refresh = value.asg.instance_refresh
    }
    if var.service.deployment_type == "ec2"
  }

  name     = each.value.name
  key_name = each.value.key_name # to SSH into instance

  # iam configuration
  create_iam_instance_profile = true
  iam_role_name               = "${var.name}-asg"
  iam_role_path               = "/ec2/"
  iam_role_description        = "ASG role for ${var.name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:${local.partition}:iam::${local.partition}:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    AmazonSSMManagedInstanceCore        = "arn:${local.partition}:iam::${local.partition}:policy/AmazonSSMManagedInstanceCore"
  }
  iam_role_tags = var.tags


  # launch template configuration
  create_launch_template = true
  tag_specifications = concat(each.value.tag_specifications, [{
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-instance" })
  }])
  instance_market_options     = each.value.instance_market_options
  instance_type               = each.value.instance_type
  image_id                    = local.image_ids[each.key]
  user_data                   = base64encode(local.user_data[each.key])
  launch_template_name        = var.name
  launch_template_description = "${var.name} asg launch template"
  update_default_version      = true
  ebs_optimized               = false # optimized ami does not support ebs_optimized
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

  // for public subnets
  // https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#network-interfaces
  network_interfaces = [
    {
      associate_public_ip_address = true
      delete_on_termination       = true
      description                 = "eth0"
      device_index                = 0
      security_groups             = [module.autoscaling_sg[each.key].security_group_id]
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
  min_size                        = floor(var.service.task_min_count * each.value.capacity_provider.weight / local.weight_total)
  max_size                        = ceil(var.service.task_max_count * each.value.capacity_provider.weight / local.weight_total)
  desired_capacity                = ceil(var.service.task_desired_count * each.value.capacity_provider.weight / local.weight_total)
  vpc_zone_identifier             = local.subnets
  health_check_type               = "EC2"
  target_group_arns               = module.elb.target_group_arns
  security_groups                 = [module.autoscaling_sg[each.key].security_group_id]
  service_linked_role_arn         = aws_iam_service_linked_role.autoscaling.arn
  instance_refresh                = each.value.instance_refresh

  # initial_lifecycle_hooks = [
  #   {
  #     name                 = "StartupLifeCycleHook"
  #     default_result       = "CONTINUE"
  #     heartbeat_timeout    = 60
  #     lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  #     notification_metadata = jsonencode({
  #       "event"         = "launch",
  #       "timestamp"     = timestamp(),
  #       "auto_scaling"  = var.name,
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
  #       "auto_scaling"  = var.name,
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
    #       resource_label         = "${module.elb.lb_arn_suffix}/${module.elb.target_group_arn_suffixes[0]}"
    #     }
    #     target_value = 800
    #   }
    # },
  }

  autoscaling_group_tags = {}
  tags                   = var.tags

  depends_on = [aws_iam_service_linked_role.autoscaling]
}

resource "aws_iam_service_linked_role" "autoscaling" {
  aws_service_name = "autoscaling.${local.dns_suffix}"
  description      = "A service linked role for autoscaling"
  custom_suffix    = var.name

  # Sometimes good sleep is required to have some IAM resources created before they can be used
  provisioner "local-exec" {
    command = "sleep 10"
  }

  tags = var.tags
}

module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.0.0"

  for_each = {
    for key, value in var.ec2 :
    key => {
      name     = "${var.name}-${key}-asg"
      key_name = value.key_name # to SSH into instance
    }
    if var.service.deployment_type == "ec2"
  }

  description = "Autoscaling group security group" # "Security group with HTTP port open for everyone, and HTTPS open just for the default security group"
  vpc_id      = var.vpc.id
  name        = each.value.name


  // only accept incoming traffic from load balancer
  computed_ingress_with_source_security_group_id = [for target in distinct([for traffic in local.traffics : {
    port     = traffic.target.port
    protocol = traffic.target.protocol
    }]) : {
    // dynamic port mapping requires all the ports open
    from_port                = var.service.deployment_type == "fargate" ? target.port : 32768
    to_port                  = var.service.deployment_type == "fargate" ? target.port : 65535
    protocol                 = local.aws_security_group_rule_protocols[target.protocol]
    description              = join(" ", ["Load", "Balancer", target.protocol, var.service.deployment_type == "fargate" ? target.port : 32768, "-", var.service.deployment_type == "fargate" ? target.port : 65535])
    source_security_group_id = module.elb_sg.security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

  // accept SSH if key
  ingress_with_cidr_blocks = each.value.key_name != null ? [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH"
      cidr_blocks = "0.0.0.0/0"
    },
  ] : []
  egress_rules = ["all-all"]

  tags = var.tags
}

resource "aws_autoscaling_attachment" "ecs" {
  for_each = {
    for key, _ in var.ec2 :
    key => {}
    if var.service.deployment_type == "ec2"
  }
  autoscaling_group_name = module.asg[each.key].autoscaling_group_name
  lb_target_group_arn    = element(module.elb.target_group_arns, 0)
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
