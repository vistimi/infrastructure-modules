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
    for v in values(var.capacity_provider) :
    v.fargate => {
      default_capacity_provider_strategy = {
        weight = v.weight_percent
        base   = v.base
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
        maximum_scaling_step_size = var.capacity_provider[key].ec2.maximum_scaling_step_size
        minimum_scaling_step_size = var.capacity_provider[key].ec2.minimum_scaling_step_size
        target_capacity           = var.capacity_provider[key].ec2.target_capacity_cpu_percent # utilization for the capacity provider
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
          type = "ingress"
          // FIXME: add me again
          // dynamic port mapping requires all the ports open
          # from_port                = var.traffic.target_port
          # to_port                  = var.traffic.target_port
          # protocol                 = "tcp"
          # description              = "Service port"
          # source_security_group_id = module.alb_sg.security_group_id
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
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
            # "ecr:GetAuthorizationToken",
            # "ecr:BatchCheckLayerAvailability",
            # "ecr:GetDownloadUrlForLayer",
            # "ecr:BatchGetImage",
            # "logs:CreateLogStream",
            # "logs:PutLogEvents",
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
            # // AmazonECSTaskExecutionRolePolicy
            # "ecr:GetAuthorizationToken",
            # "ecr:BatchCheckLayerAvailability",
            # "ecr:GetDownloadUrlForLayer",
            # "ecr:BatchGetImage",
            # "logs:CreateLogStream",
            # "logs:PutLogEvents",

            "ec2:*",
            "ecs:*",
            "logs:*",
            "s3:*",
            "ecr:*",
          ]
          effect    = "Allow"
          resources = ["*"],
          # condition = {
          #   test     = "StringEquals"
          #   variable = "aws:SourceAccount"
          #   values   = [local.account_id]
          # }
        },
        ecr = {
          actions = [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
          ]
          effect    = "Allow"
          resources = ["arn:${local.partition}:ecr:${local.region}:${local.account_id}:repository/${var.common_name}"],
          # condition = {
          #   test     = "StringEquals"
          #   variable = "aws:SourceAccount"
          #   values   = [local.account_id]
          # }
        },
        bucket-env = {
          actions   = ["s3:GetBucketLocation", "s3:ListBucket"]
          effect    = "Allow"
          resources = ["arn:${local.partition}:s3:::${var.task_definition.env_bucket_name}"],
          # condition = {
          #   test     = "StringEquals"
          #   variable = "aws:SourceAccount"
          #   values   = [local.account_id]
          # }
        },
        bucket-env-files = {
          actions   = ["s3:GetObject"]
          effect    = "Allow"
          resources = ["arn:${local.partition}:s3:::${var.task_definition.env_bucket_name}/*"],
          # condition = {
          #   test     = "StringEquals"
          #   variable = "aws:SourceAccount"
          #   values   = [local.account_id]
          # }
        },
      }


      create_tasks_iam_role = true
      task_iam_role_tags    = var.common_tags
      tasks_iam_role_statements = {
        custom = {
          actions = [

            # // AmazonEC2FullAccess
            #       "ec2:*",
            #       "elasticloadbalancing:*",
            #       "cloudwatch:*",
            #       "autoscaling:*",
            #       {
            #   "Effect" : "Allow",
            #   "Action" : "iam:CreateServiceLinkedRole",
            #   "Resource" : "*",
            #   "Condition" : {
            #     "StringEquals" : {
            #       "iam:AWSServiceName" : [
            #         "autoscaling.amazonaws.com",
            #         "ec2scheduled.amazonaws.com",
            #         "elasticloadbalancing.amazonaws.com",
            #         "spot.amazonaws.com",
            #         "spotfleet.amazonaws.com",
            #         "transitgateway.amazonaws.com"
            #       ]
            #     }
            #   }
            # }

            // AmazonECS_FullAccess
            # "application-autoscaling:DeleteScalingPolicy",
            # "application-autoscaling:DeregisterScalableTarget",
            # "application-autoscaling:DescribeScalableTargets",
            # "application-autoscaling:DescribeScalingActivities",
            # "application-autoscaling:DescribeScalingPolicies",
            # "application-autoscaling:PutScalingPolicy",
            # "application-autoscaling:RegisterScalableTarget",
            # "autoscaling:CreateAutoScalingGroup",
            # "autoscaling:CreateLaunchConfiguration",
            # "autoscaling:DeleteAutoScalingGroup",
            # "autoscaling:DeleteLaunchConfiguration",
            # "autoscaling:Describe*",
            # "autoscaling:UpdateAutoScalingGroup",
            # "cloudwatch:DeleteAlarms",
            # "cloudwatch:DescribeAlarms",
            # "cloudwatch:GetMetricStatistics",
            # "cloudwatch:PutMetricAlarm",
            # "ec2:AssociateRouteTable",
            # "ec2:AttachInternetGateway",
            # "ec2:AuthorizeSecurityGroupIngress",
            # "ec2:CancelSpotFleetRequests",
            # "ec2:CreateInternetGateway",
            # "ec2:CreateLaunchTemplate",
            # "ec2:CreateRoute",
            # "ec2:CreateRouteTable",
            # "ec2:CreateSecurityGroup",
            # "ec2:CreateSubnet",
            # "ec2:CreateVpc",
            # "ec2:DeleteLaunchTemplate",
            # "ec2:DeleteSubnet",
            # "ec2:DeleteVpc",
            # "ec2:Describe*",
            # "ec2:DetachInternetGateway",
            # "ec2:DisassociateRouteTable",
            # "ec2:ModifySubnetAttribute",
            # "ec2:ModifyVpcAttribute",
            # "ec2:RequestSpotFleet",
            # "ec2:RunInstances",
            # "ecs:*",
            # "servicediscovery:CreatePrivateDnsNamespace",
            # "servicediscovery:CreateService",
            # "servicediscovery:DeleteService",
            # "servicediscovery:GetNamespace",
            # "servicediscovery:GetOperation",
            # "servicediscovery:GetService",
            # "servicediscovery:ListNamespaces",
            # "servicediscovery:ListServices",
            # "servicediscovery:UpdateService",
            # "sns:ListTopics"
            #  ssm:GetParameter",
            # "ssm:GetParameters",
            # "ssm:GetParametersByPath"

            "s3:*",
            "iam:*",
            "elasticloadbalancing:*",
            "cloudwatch:*",
            "autoscaling:*",
            "application-autoscaling:*",
            "ec2:*",
            "ecs:*",
            "events:*",
            "logs:*",
            "servicediscovery:*",
            "sns:*",
            "ssm:*",
          ]
          effect    = "Allow"
          resources = ["*"],
          # condition = {
          #   test     = "StringEquals"
          #   variable = "aws:SourceAccount"
          #   values   = [local.account_id]
          # }
        },
      }
      tasks_iam_role_policies = {
        AmazonEC2FullAccess  = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
        AmazonECS_FullAccess = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
      }

      memory                   = var.task_definition.memory
      cpu                      = var.task_definition.cpu
      family                   = var.common_name
      requires_compatibilities = var.service.use_fargate ? ["FARGATE"] : ["EC2"]
      // https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/networking-networkmode.html
      // "host" one container, "bridge" is default and supports multiple containers and dynamic port mapping
      network_mode = var.service.use_fargate ? "awsvpc" : "bridge" // "host" for single instance

      container_definitions = {
        "${var.common_name}" = {
          name = var.common_name
          environment_files = [
            {
              "value" = "arn:${local.partition}:s3:::${var.task_definition.env_bucket_name}/${var.task_definition.env_file_name}",
              "type"  = "s3"
            }
          ]

          # https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_PortMapping.html
          // port is defined in laod balancer
          port_mappings = [
            {
              containerPort = var.traffic.target_port
              # appProtocol   = var.traffic.target_protocol
              # containerPortRange = "32768-65535"
              hostPort = var.service.use_fargate ? var.traffic.target_port : 0
              name     = "container-port"
              protocol = "tcp"
            }
          ]
          memory             = var.task_definition.memory
          memory_reservation = var.task_definition.memory_reservation
          cpu                = var.task_definition.cpu
          log_configuration  = null # other driver than json-file

          // fargate AMI
          runtime_platform = var.service.use_fargate ? {
            "operatingSystemFamily" = var.fargate.os,
            "cpuArchitecture"       = var.fargate.architecture
          } : null

          image     = "${local.account_id}.dkr.ecr.${local.region}.${local.dns_suffix}/${var.common_name}:${var.task_definition.registry_image_tag}"
          essential = true
        }
      }
    }
  }

  tags = var.common_tags
}
