locals {
  fargate_capacity_provider_keys = {
    ON_DEMAND = "FARGATE"
    SPOT      = "FARGATE_SPOT"
  }
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.2.0"

  cluster_name = var.name

  # capacity providers
  default_capacity_provider_use_fargate = var.ecs.service.ec2 != null ? false : true
  fargate_capacity_providers = try({
    for capacity in var.ecs.service.fargate.capacities :
    local.fargate_capacity_provider_keys[capacity.type] => {
      default_capacity_provider_strategy = {
        weight = capacity.weight
        base   = capacity.base
      }
    }
  }, {})
  autoscaling_capacity_providers = {
    for capacity in var.ecs.service.ec2.capacities :
    "${var.name}-${capacity.type}" => {
      name                   = "${var.name}-${capacity.type}"
      auto_scaling_group_arn = module.asg.autoscaling.group_arn
      managed_scaling = {
        // https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-quotas.html
        maximum_scaling_step_size = capacity.maximum_scaling_step_size == null ? max(min(ceil((var.ecs.service.task.max_size - var.ecs.service.task.min_size) / 3), 10), 1) : capacity.maximum_scaling_step_size
        minimum_scaling_step_size = capacity.minimum_scaling_step_size == null ? max(min(floor((var.ecs.service.task.max_size - var.ecs.service.task.min_size) / 10), 10), 1) : capacity.minimum_scaling_step_size
        target_capacity           = capacity.target_capacity_cpu_percent # utilization for the capacity provider
        status                    = "ENABLED"
        instance_warmup_period    = 300
        default_capacity_provider_strategy = {
          base   = capacity.base
          weight = capacity.weight
        }
      }
      managed_termination_protection = "DISABLED"
    }
  }

  services = {
    "${var.name}-${var.ecs.service.name}" = {
      #------------
      # Service
      #------------
      force_new_deployment               = true
      launch_type                        = var.ecs.service.ec2 != null ? "EC2" : "FARGATE"
      enable_autoscaling                 = true
      autoscaling_min_capacity           = var.ecs.service.task.min_size
      desired_count                      = var.ecs.service.task.desired_size
      autoscaling_max_capacity           = var.ecs.service.task.max_size
      deployment_maximum_percent         = var.ecs.service.task.maximum_percent         // max % tasks running required
      deployment_minimum_healthy_percent = var.ecs.service.task.minimum_healthy_percent // min % tasks running required
      deployment_circuit_breaker         = var.ecs.service.task.circuit_breaker

      # network awsvpc for fargate
      subnets          = var.ecs.service.ec2 != null ? null : local.subnets
      assign_public_ip = var.ecs.service.ec2 != null ? null : true // if private subnets, use NAT

      load_balancer = {
        service = {
          target_group_arn = element(module.elb.target_group.arns, 0) // one LB per target group
          container_name   = "${var.name}-container"
          container_port   = element([for traffic in local.traffics : traffic.target.port if traffic.base == true || length(local.traffics) == 1], 0)
        }
      }

      # security group
      subnet_ids = local.subnets
      security_group_rules = merge(
        {
          for target in distinct([for traffic in local.traffics : {
            port     = traffic.target.port
            protocol = traffic.target.protocol
            }]) : join("-", ["elb", "ingress", target.protocol, target.port]) => {
            type                     = "ingress"
            from_port                = target.port
            to_port                  = target.port
            protocol                 = local.layer7_to_layer4_mapping[target.protocol]
            description              = "Service ${target.protocol} port ${target.port}"
            source_security_group_id = module.elb.security_group.id
          }
        },
        {
          egress_all = {
            type        = "egress"
            from_port   = 0
            to_port     = 0
            protocol    = "-1"
            cidr_blocks = ["0.0.0.0/0"]
            description = "Allow all traffic"
          }
      })

      #---------------------
      # Task definition
      #---------------------
      create_task_exec_iam_role = true
      task_exec_iam_role_tags   = var.tags
      task_exec_iam_statements = merge(
        {
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
              "ecs:StartTask",
            ]
            effect    = "Allow"
            resources = ["*"],
          },
        },
        try({
          bucket-env = {
            actions   = ["s3:GetBucketLocation", "s3:ListBucket"]
            effect    = "Allow"
            resources = ["arn:${local.partition}:s3:::${var.ecs.service.task.container.env_file.bucket_name}"],
          },
          bucket-env-files = {
            actions   = ["s3:GetObject"]
            effect    = "Allow"
            resources = ["arn:${local.partition}:s3:::${var.ecs.service.task.container.env_file.bucket_name}/*"],
          },
        }, {}),
        try(var.ecs.service.task.container.docker.registry.ecr != null, false) ? {
          ecr = {
            actions = [
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "ecr-public:GetAuthorizationToken",
              "ecr-public:BatchCheckLayerAvailability",
            ]
            effect    = "Allow"
            resources = ["arn:${local.partition}:${local.ecr_services[var.ecs.service.task.container.docker.registry.ecr.privacy]}:${local.ecr_repository_region_name}:${local.ecr_repository_account_id}:repository/${var.ecs.service.task.container.docker.repository.name}"]
          },
        } : {}
      )

      create_tasks_iam_role = true
      task_iam_role_tags    = var.tags
      tasks_iam_role_statements = {
        custom = {
          actions = [
            "ec2:Describe*",
          ]
          effect    = "Allow"
          resources = ["*"],
        },
      }

      # Task definition
      memory                   = var.ecs.service.task.container.memory
      cpu                      = var.ecs.service.task.container.cpu
      family                   = var.name
      requires_compatibilities = var.ecs.service.ec2 != null ? ["EC2"] : ["FARGATE"]
      // https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/networking-networkmode.html
      network_mode = var.ecs.service.ec2 != null ? "bridge" : "awsvpc" // "host" for single instance

      placement_constraints = var.ecs.service.ec2 != null && alltrue([for key, value in var.ecs.service.ec2 : value.architecture == "inf"]) ? [
        {
          "type" : "memberOf",
          "expression" : "attribute:ecs.os-type == linux"
        },
        {
          "type" : "memberOf",
          "expression" : "attribute:ecs.instance-type == ${element(distinct([for key, value in var.ecs.service.ec2 : value.instance_type]), 0)}"
        }
      ] : []

      volumes = var.ecs.service.task.volumes

      # Task definition container(s)
      # https://github.com/terraform-aws-modules/terraform-aws-ecs/blob/master/modules/container-definition/variables.tf
      container_definitions = {
        "${var.name}-${var.ecs.service.task.container.name}" = {

          # enable_cloudwatch_logging              = true
          # create_cloudwatch_log_group            = true
          # cloudwatch_log_group_retention_in_days = 30
          # cloudwatch_log_group_kms_key_id        = null

          # name = var.name
          environment_files = try([{
            "value" = "arn:${local.partition}:s3:::${var.ecs.service.task.container.env_file.bucket_name}/${var.ecs.service.task.container.env_file.file_name}",
            "type"  = "s3"
            }
          ], [])
          environment = var.ecs.service.task.container.environment,

          # https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_PortMapping.html
          port_mappings = [for target in distinct([for traffic in local.traffics : {
            port             = traffic.target.port
            protocol         = traffic.target.protocol
            protocol_version = traffic.target.protocol_version
            }]) : {
            containerPort = target.port
            hostPort      = var.ecs.service.ec2 != null ? 0 : target.port // "host" network can use target port 
            name          = join("-", ["container", target.protocol, target.port])
            protocol      = target.protocol_version == "grpc" ? "tcp" : target.protocol // TODO: local.layer7_to_layer4_mapping[target.protocol]
            }
          ]
          memory             = var.ecs.service.task.container.memory
          memory_reservation = var.ecs.service.task.container.memory_reservation
          cpu                = var.ecs.service.task.container.cpu
          log_configuration  = null # other driver than json-file

          resource_requirements = concat(
            var.ecs.service.task.container.resource_requirements,
            var.ecs.service.ec2 != null && alltrue([for key, value in var.ecs.service.ec2 : value.architecture == "gpu"]) ? [{
              "type" : "GPU",
              "value" : "${var.ecs.service.task.container.gpu}"
            }] : []
          )

          command                  = var.ecs.service.task.container.command
          entrypoint               = var.ecs.service.task.container.entrypoint
          health_check             = var.ecs.service.task.container.health_check
          readonly_root_filesystem = var.ecs.service.task.container.readonly_root_filesystem
          user                     = var.ecs.service.task.container.user
          volumes_from             = var.ecs.service.task.container.volumes_from
          working_directory        = var.ecs.service.task.container.working_directory
          mount_points             = var.ecs.service.task.container.mount_points
          linux_parameters         = var.ecs.service.task.container.linux_parameters

          // fargate AMI
          runtime_platform = var.ecs.service.ec2 != null ? null : {
            "operatingSystemFamily" = local.fargate_os[var.ecs.service.fargate.os],
            "cpuArchitecture"       = local.fargate_architecture[var.ecs.service.fargate.architecture],
          }

          image = join("/", compact([
            local.docker_registry_name,
            join(":", compact([var.ecs.service.task.container.docker.repository.name, try(var.ecs.service.task.container.docker.image.tag, "")]))
          ]))

          essential = true
        }
      }
    }
  }

  tags = var.tags
}
