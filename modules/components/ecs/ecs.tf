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

  default_capacity_provider_use_fargate = var.deployment.use_fargate ? true : false // TODO: remove because only for default
  fargate_capacity_providers = {
    for v in values(var.capacity_provider) :
    v.fargate => {
      default_capacity_provider_strategy = {
        weight = v.weight_percent
        base   = v.base
      }
    }
    if var.deployment.use_fargate
  }
  autoscaling_capacity_providers = {
    for key, value in var.capacity_provider :
    key => {
      name                   = "${var.common_name}-${key}"
      auto_scaling_group_arn = module.asg[key].autoscaling_group_arn
      managed_scaling = {
        maximum_scaling_step_size = var.capacity_provider[key].scaling.maximum_scaling_step_size
        minimum_scaling_step_size = var.capacity_provider[key].scaling.minimum_scaling_step_size
        target_capacity           = var.capacity_provider[key].scaling.target_capacity_cpu_percent # utilization for the capacity provider
        status                    = "ENABLED"
        instance_warmup_period    = 300
        default_capacity_provider_strategy = {
          base   = value.base
          weight = value.weight_percent
        }
      }
      managed_termination_protection = "DISABLED"
    }
    if !var.deployment.use_fargate
  }

  services = {
    "${var.common_name}" = {
      #---------------------
      # Task definition
      #---------------------
      create_task_exec_iam_role = true
      # task_exec_iam_role_arn    = aws_iam_role.ecs_execution.arn
      task_exec_iam_role_tags = var.common_tags
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
        # user-assume = {
        #   actions = ["sts:AssumeRole"]
        #   effect  = "Allow"
        #   principals = {
        #     type        = "AWS"
        #     identifiers = [local.account_arn]
        #   }
        #   # condition = {
        #   #   test     = "Bool"
        #   #   variable = "aws:MultiFactorAuthPresent"
        #   #   values   = ["true"]
        #   # }
        # }
      }


      create_tasks_iam_role = true
      # tasks_iam_role_arn    = aws_iam_role.ecs_task.arn
      task_iam_role_tags = var.common_tags
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
        # user-assume = {
        #   actions = ["sts:AssumeRole"]
        #   effect  = "Allow"
        #   principals = {
        #     type        = "AWS"
        #     identifiers = [local.account_arn]
        #   }
        #   # condition = {
        #   #   test     = "Bool"
        #   #   variable = "aws:MultiFactorAuthPresent"
        #   #   values   = ["true"]
        #   # }
        # }
      }
      tasks_iam_role_policies = {
        AmazonEC2FullAccess  = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
        AmazonECS_FullAccess = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
      }

      memory                   = var.task_definition.memory
      cpu                      = var.task_definition.cpu
      family                   = var.common_name
      requires_compatibilities = var.deployment.use_fargate ? ["FARGATE"] : ["EC2"]
      network_mode             = var.deployment.use_fargate ? "awsvpc" : "host" // "host", "bridge" is default and supports multiple container per instance

      # Container definition(s)
      container_definitions = {

        "${var.common_name}" = {
          name = var.common_name
          environment_files = [
            {
              "value" = "arn:${local.partition}:s3:::${var.task_definition.env_bucket_name}/${var.task_definition.env_file_name}",
              "type"  = "s3"
            }
          ]

          port_mappings      = var.task_definition.port_mapping
          memory             = var.task_definition.memory
          memory_reservation = var.task_definition.memory_reservation
          cpu                = var.task_definition.cpu
          log_configuration  = null
          # var.deployment.use_fargate ? {
          #   "logDriver" = "awslogs",
          #   "options" = {
          #     "awslogs-group"         = aws_cloudwatch_log_group.cluster.name
          #     "awslogs-region"        = "${local.region}",
          #     "awslogs-stream-prefix" = "/${var.log.prefix}"
          #   }
          # } : null

          // fargate AMI
          runtime_platform = var.deployment.use_fargate ? {
            "operatingSystemFamily" = var.instance.fargate.os,
            "cpuArchitecture"       = var.instance.fargate.architecture
          } : null

          image     = "${local.account_id}.dkr.ecr.${local.region}.${local.dns_suffix}/${var.common_name}:${var.task_definition.registry_image_tag}"
          essential = true
        }
      }

      #------------
      # Service
      #------------
      desired_count = var.service_task_desired_count
      launch_type   = var.deployment.use_fargate ? "FARGATE" : "EC2"
      # capacity_provider_strategy = {
      #   for key, value in var.capacity_provider :
      #   key => {
      #     capacity_provider = "${var.common_name}-${key}"
      #     base              = value.base
      #     weight            = value.weight_percent
      #   }
      #   if !var.deployment.use_fargate
      # }

      # network awsvpc for fargate
      subnets          = local.subnets
      assign_public_ip = true // if private subnets, use NAT
      # security_groups  = [module.service_sg.security_group_id]

      load_balancer = {
        service = {
          target_group_arn = module.alb.target_group_arns[0] // one LB per target group
          container_name   = var.common_name
          container_port   = var.traffic.target_port
        }
      }

      subnet_ids = local.subnets
      security_group_rules = {
        alb_ingress = {
          type = "ingress"
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
    }
  }

  tags = var.common_tags
}
