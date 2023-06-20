locals {
  // needs ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true in userdata
  // aggregate for only one task definition
  # single_instances = [
  #   for key, value in var.ec2 :
  #   value.asg.desired_size == 1 && value.asg.max_size == 1
  # ]
  # single_instance = alltrue(local.single_instances) && length(local.single_instances) == 1
  single_instance = false
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/${var.log.prefix}/${var.common_name}"
  retention_in_days = var.log.retention_days

  tags = var.common_tags
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.2.0"

  cluster_name = var.common_name

  create_cloudwatch_log_group = false
  # cloudwatch_log_group_retention_in_days = var.log.retention_days

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.cluster.name
      }
    }
  }

  # capacity providers
  default_capacity_provider_use_fargate = var.service.use_fargate ? true : false
  fargate_capacity_providers = {
    for key, cp in var.capacity_provider :
    var.fargate.capacity_provider[key] => {
      default_capacity_provider_strategy = {
        weight = cp.weight_percent
        base   = cp.base
      }
    }
    if var.service.use_fargate
  }
  autoscaling_capacity_providers = {
    for key, value in var.capacity_provider :
    key => {
      name                   = "${var.common_name}-${key}"
      auto_scaling_group_arn = module.asg[key].autoscaling_group_arn
      managed_scaling = {
        maximum_scaling_step_size = var.ec2[key].capacity_provider.maximum_scaling_step_size
        minimum_scaling_step_size = var.ec2[key].capacity_provider.minimum_scaling_step_size
        target_capacity           = var.ec2[key].capacity_provider.target_capacity_cpu_percent # utilization for the capacity provider
        status                    = "ENABLED"
        instance_warmup_period    = 300
        default_capacity_provider_strategy = {
          base   = value.base
          weight = value.weight_percent
        }
      }
      managed_termination_protection = "DISABLED"
    }
    if !var.service.use_fargate
  }

  services = {
    "${var.common_name}" = {
      #------------
      # Service
      #------------
      force_new_deployment               = true
      launch_type                        = var.service.use_fargate ? "FARGATE" : "EC2"
      desired_count                      = var.service.task_desired_count                 // amount of tasks desired
      deployment_maximum_percent         = var.service.deployment_maximum_percent         // max % tasks running required
      deployment_minimum_healthy_percent = var.service.deployment_minimum_healthy_percent // min % tasks running required
      deployment_circuit_breaker         = var.service.deployment_circuit_breaker

      # network awsvpc for fargate
      subnets          = var.service.use_fargate ? local.subnets : null
      assign_public_ip = var.service.use_fargate ? true : null // if private subnets, use NAT

      load_balancer = {
        service = {
          target_group_arn = module.alb.target_group_arns[0] // one LB per target group
          container_name   = var.common_name
          container_port   = var.traffic.target_port
        }
      }

      # security group
      subnet_ids = local.subnets
      security_group_rules = {
        alb_ingress = {
          type                     = "ingress"
          from_port                = var.traffic.target_port
          to_port                  = var.traffic.target_port
          protocol                 = "tcp"
          description              = "Service port"
          source_security_group_id = module.alb_sg.security_group_id
        }
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }

      #---------------------
      # Task definition
      #---------------------
      create_task_exec_iam_role = true
      task_exec_iam_role_tags   = var.common_tags
      task_exec_iam_statements = {
        custom = {
          actions = [
            # // AmazonECSTaskExecutionRolePolicy for fargate 
            # // AmazonEC2ContainerServiceforEC2Role for ec2
            "ec2:DescribeTags",
            "ecs:CreateCluster",
            "ecs:DeregisterContainerInstance",
            "ecs:DiscoverPollEndpoint",
            "ecs:Poll",
            "ecs:RegisterContainerInstance",
            "ecs:StartTelemetrySession",
            "ecs:UpdateContainerInstancesState",
            "ecs:Submit*",
          ]
          effect    = "Allow"
          resources = ["*"],
        },
        ecr = {
          actions = [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
          ]
          effect    = "Allow"
          resources = ["arn:${local.partition}:ecr:${local.region}:${local.account_id}:repository/${var.task_definition.repository_name}"],
        },
        bucket-env = {
          actions   = ["s3:GetBucketLocation", "s3:ListBucket"]
          effect    = "Allow"
          resources = ["arn:${local.partition}:s3:::${var.task_definition.env_bucket_name}"],
        },
        bucket-env-files = {
          actions   = ["s3:GetObject"]
          effect    = "Allow"
          resources = ["arn:${local.partition}:s3:::${var.task_definition.env_bucket_name}/*"],
        },
        log-group = {
          actions = [
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ]
          effect    = "Allow"
          resources = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:${aws_cloudwatch_log_group.cluster.name}"],
        },
      }


      create_tasks_iam_role = true
      task_iam_role_tags    = var.common_tags
      tasks_iam_role_statements = {
        custom = {
          actions = [
            "ec2:Describe*",
          ]
          effect    = "Allow"
          resources = ["*"],
        },
        log-stream = {
          actions = [
            "logs:PutLogEvents",
          ]
          effect    = "Allow"
          resources = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:${aws_cloudwatch_log_group.cluster.name}:log-stream:*"],
        },
      }

      # Task definition
      memory                   = var.task_definition.memory
      cpu                      = var.task_definition.cpu
      family                   = var.common_name
      requires_compatibilities = var.service.use_fargate ? ["FARGATE"] : ["EC2"]
      // https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/networking-networkmode.html
      network_mode = var.service.use_fargate ? "awsvpc" : local.single_instance ? "host" : "bridge" // "host" for single instance

      # Task definition container(s)
      container_definitions = {
        "${var.common_name}" = {
          name = var.common_name
          environment_files = [
            {
              "value" = "arn:${local.partition}:s3:::${var.task_definition.env_bucket_name}/${var.task_definition.env_file_name}",
              "type"  = "s3"
            }
          ]
          environment = var.task_definition.environment,

          # https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_PortMapping.html
          port_mappings = [
            {
              containerPort = var.traffic.target_port
              # appProtocol   = var.traffic.target_protocol
              # containerPortRange = "32768-65535"
              hostPort = var.service.use_fargate || local.single_instance ? var.traffic.target_port : 0 // "host" network can use target port 
              name     = "container-port"
              protocol = "tcp"
            }
          ]
          # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-ecs-taskdefinition-tmpfs.html#aws-properties-ecs-taskdefinition-tmpfs-properties
          tmpfs              = var.task_definition.tmpfs
          memory             = var.task_definition.memory
          memory_reservation = var.task_definition.memory_reservation
          cpu                = var.task_definition.cpu
          log_configuration  = null # other driver than json-file

          // fargate AMI
          runtime_platform = var.service.use_fargate ? {
            "operatingSystemFamily" = var.fargate.os,
            "cpuArchitecture"       = var.fargate.architecture
          } : null

          image     = "${local.account_id}.dkr.ecr.${local.region}.${local.dns_suffix}/${var.task_definition.repository_name}:${var.task_definition.repository_image_tag}"
          essential = true
        }
      }
    }
  }

  tags = var.common_tags
}
