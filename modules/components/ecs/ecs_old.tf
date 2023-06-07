# resource "aws_iam_policy" "ecs_logs" {
#   name = "${var.common_name}-ecs-task-container-logs"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#           "logs:CreateLogStream",
#           "logs:PutLogEvents",
#           "logs:DescribeLogStreams",
#           "logs:PutRetentionPolicy",
#           "logs:CreateLogGroup"
#         ]
#         Effect   = "Allow"
#         Resource = "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:${aws_cloudwatch_log_group.cluster.name}",
#       },
#       {
#         Action = [
#           "logs:GetLogEvents",
#           "logs:PutLogEvents"
#         ]
#         Effect   = "Allow"
#         Resource = "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:${aws_cloudwatch_log_group.cluster.name}:log-stream:*",
#       },
#     ]
#   })
# }


# #---------------
# #   Policies
# #---------------

# # Managed policies

# # https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEC2FullAccess.html
# data "aws_iam_policy" "aws_ec2_full_access_policy" {
#   name = "AmazonEC2FullAccess"
# }

# # Admin access to ECS
# data "aws_iam_policy" "aws_ecs_full_access_policy" {
#   name = "AmazonECS_FullAccess"
# }

# resource "aws_iam_policy" "ecr" {
#   name = "${var.common_name}-ecr"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#           "ecr:GetAuthorizationToken",
#           "ecr:BatchCheckLayerAvailability",
#           "ecr:GetDownloadUrlForLayer",
#           "ecr:BatchGetImage",
#         ]
#         Effect   = "Allow"
#         Resource = "arn:${local.partition}:ecr:${local.region}:${local.account_id}:repository/${var.common_name}"
#       }
#     ]
#   })
# }

# resource "aws_iam_policy" "bucket_env" {
#   name = "${var.common_name}-ecs-task-container-s3-env"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
#         Effect   = "Allow"
#         Resource = "arn:${local.partition}:s3:::${var.task_definition.env_bucket_name}",
#       },
#       {
#         Action   = ["s3:GetObject"]
#         Effect   = "Allow"
#         Resource = "arn:${local.partition}:s3:::${var.task_definition.env_bucket_name}/*",
#       },
#       # {
#       #   "Action" : ["kms:GetPublicKey", "kms:GetKeyPolicy", "kms:DescribeKey"],
#       #   "Effect" : "Allow",
#       #   "Resource" : "*",
#       # }
#     ]
#   })
# }



# data "aws_iam_policy_document" "ecs_task_assume_role" {
#   statement {
#     sid     = "ECSTaskAssumeRole"
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["ecs-tasks.${local.dns_suffix}"]
#     }

#     # # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html#create_task_iam_policy_and_role
#     # condition {
#     #   test     = "ArnLike"
#     #   variable = "aws:SourceArn"
#     #   values   = ["arn:${local.partition}:ecs:${local.region}:${local.account_id}:*"]
#     # }

#     # condition {
#     #   test     = "StringEquals"
#     #   variable = "aws:SourceAccount"
#     #   values   = [local.account_id]
#     # }
#   }
# }

# # Roles

# # grants the ***ECS and Fargate*** agents permission to make AWS API calls on your behalf
# # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
# resource "aws_iam_role" "ecs_execution" {
#   name = "${var.common_name}-ecs-execution"

#   assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
#   managed_policy_arns = [
#     aws_iam_policy.ecs_execution.arn,
#     # aws_iam_policy.ecr.arn,
#     # aws_iam_policy.bucket_env.arn,
#     # aws_iam_policy.ecs_logs.arn,
#   ]

#   tags = var.common_tags
# }

# resource "aws_iam_policy" "ecs_execution" {
#   name = "${var.common_name}-ecs-execution"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#           # // AmazonECSTaskExecutionRolePolicy for fargate 
#           # "ecr:GetAuthorizationToken",
#           # "ecr:BatchCheckLayerAvailability",
#           # "ecr:GetDownloadUrlForLayer",
#           # "ecr:BatchGetImage",
#           # "logs:CreateLogStream",
#           # "logs:PutLogEvents",
#           # // AmazonEC2ContainerServiceforEC2Role for ec2
#           # "ec2:DescribeTags",
#           # "ecs:CreateCluster",
#           # "ecs:DeregisterContainerInstance",
#           # "ecs:DiscoverPollEndpoint",
#           # "ecs:Poll",
#           # "ecs:RegisterContainerInstance",
#           # "ecs:StartTelemetrySession",
#           # "ecs:UpdateContainerInstancesState",
#           # "ecs:Submit*",
#           # "ecr:GetAuthorizationToken",
#           # "ecr:BatchCheckLayerAvailability",
#           # "ecr:GetDownloadUrlForLayer",
#           # "ecr:BatchGetImage",
#           # "logs:CreateLogStream",
#           # "logs:PutLogEvents",
#           # // AmazonECSTaskExecutionRolePolicy
#           # "ecr:GetAuthorizationToken",
#           # "ecr:BatchCheckLayerAvailability",
#           # "ecr:GetDownloadUrlForLayer",
#           # "ecr:BatchGetImage",
#           # "logs:CreateLogStream",
#           # "logs:PutLogEvents",

#           "ec2:*",
#           "ecs:*",
#           "logs:*",
#           "s3:*",
#           "ecr:*",
#         ]
#         Effect   = "Allow"
#         Resource = "*",
#       },
#     ]
#   })
# }

# # grants ***containers*** in the task permission to call AWS APIs on your behalf.
# resource "aws_iam_role" "ecs_task" {
#   name = "${var.common_name}-ecs-task-container"

#   assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
#   managed_policy_arns = [
#     aws_iam_policy.ecs_task.arn,
#     data.aws_iam_policy.aws_ec2_full_access_policy.arn,
#     data.aws_iam_policy.aws_ecs_full_access_policy.arn, // TODO: try replace it
#     # aws_iam_policy.ecs_logs.arn,
#     # aws_iam_policy.bucket_env.arn, // FIXME: remove me
#   ]

#   tags = var.common_tags
# }

# resource "aws_iam_policy" "ecs_task" {
#   name = "${var.common_name}-ecs-task"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [

#           # // AmazonEC2FullAccess
#           #       "ec2:*",
#           #       "elasticloadbalancing:*",
#           #       "cloudwatch:*",
#           #       "autoscaling:*",
#           #       {
#           #   "Effect" : "Allow",
#           #   "Action" : "iam:CreateServiceLinkedRole",
#           #   "Resource" : "*",
#           #   "Condition" : {
#           #     "StringEquals" : {
#           #       "iam:AWSServiceName" : [
#           #         "autoscaling.amazonaws.com",
#           #         "ec2scheduled.amazonaws.com",
#           #         "elasticloadbalancing.amazonaws.com",
#           #         "spot.amazonaws.com",
#           #         "spotfleet.amazonaws.com",
#           #         "transitgateway.amazonaws.com"
#           #       ]
#           #     }
#           #   }
#           # }

#           // AmazonECS_FullAccess
#           # "application-autoscaling:DeleteScalingPolicy",
#           # "application-autoscaling:DeregisterScalableTarget",
#           # "application-autoscaling:DescribeScalableTargets",
#           # "application-autoscaling:DescribeScalingActivities",
#           # "application-autoscaling:DescribeScalingPolicies",
#           # "application-autoscaling:PutScalingPolicy",
#           # "application-autoscaling:RegisterScalableTarget",
#           # "autoscaling:CreateAutoScalingGroup",
#           # "autoscaling:CreateLaunchConfiguration",
#           # "autoscaling:DeleteAutoScalingGroup",
#           # "autoscaling:DeleteLaunchConfiguration",
#           # "autoscaling:Describe*",
#           # "autoscaling:UpdateAutoScalingGroup",
#           # "cloudwatch:DeleteAlarms",
#           # "cloudwatch:DescribeAlarms",
#           # "cloudwatch:GetMetricStatistics",
#           # "cloudwatch:PutMetricAlarm",
#           # "ec2:AssociateRouteTable",
#           # "ec2:AttachInternetGateway",
#           # "ec2:AuthorizeSecurityGroupIngress",
#           # "ec2:CancelSpotFleetRequests",
#           # "ec2:CreateInternetGateway",
#           # "ec2:CreateLaunchTemplate",
#           # "ec2:CreateRoute",
#           # "ec2:CreateRouteTable",
#           # "ec2:CreateSecurityGroup",
#           # "ec2:CreateSubnet",
#           # "ec2:CreateVpc",
#           # "ec2:DeleteLaunchTemplate",
#           # "ec2:DeleteSubnet",
#           # "ec2:DeleteVpc",
#           # "ec2:Describe*",
#           # "ec2:DetachInternetGateway",
#           # "ec2:DisassociateRouteTable",
#           # "ec2:ModifySubnetAttribute",
#           # "ec2:ModifyVpcAttribute",
#           # "ec2:RequestSpotFleet",
#           # "ec2:RunInstances",
#           # "ecs:*",
#           # "servicediscovery:CreatePrivateDnsNamespace",
#           # "servicediscovery:CreateService",
#           # "servicediscovery:DeleteService",
#           # "servicediscovery:GetNamespace",
#           # "servicediscovery:GetOperation",
#           # "servicediscovery:GetService",
#           # "servicediscovery:ListNamespaces",
#           # "servicediscovery:ListServices",
#           # "servicediscovery:UpdateService",
#           # "sns:ListTopics"
#           #  ssm:GetParameter",
#           # "ssm:GetParameters",
#           # "ssm:GetParametersByPath"

#           "s3:*",
#           "iam:*",
#           "elasticloadbalancing:*",
#           "cloudwatch:*",
#           "autoscaling:*",
#           "application-autoscaling:*",
#           "ec2:*",
#           "ecs:*",
#           "events:*",
#           "logs:*",
#           "servicediscovery:*",
#           "sns:*",
#           "ssm:*",
#         ]
#         Effect   = "Allow"
#         Resource = "*",
#       },
#     ]
#   })
# }

# # ------------------------
# #     Task definition
# # ------------------------
# resource "aws_ecs_task_definition" "service" {

#   execution_role_arn       = aws_iam_role.ecs_execution.arn
#   task_role_arn            = aws_iam_role.ecs_task.arn
#   memory                   = var.task_definition.memory
#   cpu                      = var.task_definition.cpu
#   family                   = var.common_name
#   requires_compatibilities = var.deployment.use_fargate ? ["FARGATE"] : ["EC2"]
#   network_mode             = var.deployment.use_fargate ? "awsvpc" : "host" // "bridge" # bridge supports multiple container per instance

#   // only one container per instance
#   container_definitions = jsonencode([
#     {
#       name = var.common_name
#       environmentFiles : [
#         {
#           "value" : "arn:${local.partition}:s3:::${var.task_definition.env_bucket_name}/${var.task_definition.env_file_name}",
#           "type" : "s3"
#         }
#       ]
#       # environment : [
#       #   {
#       #     "name" : "CLOUD_HOST",
#       #     "value" : "aws"
#       #   },
#       #   {
#       #     "name" : "COMMON_NAME",
#       #     "value" : var.common_name
#       #   },
#       #   {
#       #     "name" : "FLICKR_PRIVATE_KEY",
#       #     "value" : "123"
#       #   },
#       #   {
#       #     "name" : "FLICKR_PUBLIC_KEY",
#       #     "value" : "123"
#       #   },
#       #   {
#       #     "name" : "UNSPLASH_PRIVATE_KEY",
#       #     "value" : "123"
#       #   },
#       #   {
#       #     "name" : "UNSPLASH_PUBLIC_KEY",
#       #     "value" : "123"
#       #   },
#       #   {
#       #     "name" : "PEXELS_PUBLIC_KEY",
#       #     "value" : "123"
#       #   },
#       #   {
#       #     "name" : "AWS_REGION",
#       #     "value" : "us-west-1"
#       #   },
#       #   {
#       #     "name" : "AWS_ACCESS_KEY",
#       #     "value" : "123"
#       #   },
#       #   {
#       #     "name" : "AWS_SECRET_KEY",
#       #     "value" : "123"
#       #   }
#       # ],

#       portMappings : var.task_definition.port_mapping
#       memory            = var.task_definition.memory
#       memoryReservation = var.task_definition.memory_reservation
#       cpu               = var.task_definition.cpu
#       logConfiguration : {
#         "logDriver" : "awslogs",
#         "options" : {
#           "awslogs-group" : aws_cloudwatch_log_group.cluster.name
#           "awslogs-region" : "${local.region}",
#           "awslogs-stream-prefix" : "/${var.log.prefix}"
#         }
#       }

#       // fargate AMI
#       runtimePlatform = var.deployment.use_fargate ? {
#         "operatingSystemFamily" : var.instance.fargate.os,
#         "cpuArchitecture" : var.instance.fargate.architecture
#       } : null

#       image     = "${local.account_id}.dkr.ecr.${local.region}.${local.dns_suffix}/${var.common_name}:${var.task_definition.registry_image_tag}"
#       essential = true
#     }
#   ])
# }

# #-----------------
# #     Cluster
# #-----------------
# resource "aws_ecs_cluster" "this" {
#   name = var.common_name

#   configuration {
#     execute_command_configuration {
#       logging = "OVERRIDE"
#       log_configuration {
#         cloud_watch_encryption_enabled = true
#         cloud_watch_log_group_name     = aws_cloudwatch_log_group.cluster.name
#       }
#     }
#   }
# }

# #----------------------------
# #     Capacity Providers
# #----------------------------
# # EC2 capacity providers
# resource "aws_ecs_capacity_provider" "this" {
#   for_each = {
#     for key, value in var.capacity_provider :
#     key => {
#       name                      = "${var.common_name}-${key}"
#       maximum_scaling_step_size = var.capacity_provider[key].scaling.maximum_scaling_step_size
#       minimum_scaling_step_size = var.capacity_provider[key].scaling.minimum_scaling_step_size
#       target_capacity           = var.capacity_provider[key].scaling.target_capacity_cpu_percent # utilization for the capacity provider
#     }
#     if !var.deployment.use_fargate
#   }

#   name = each.value.name

#   auto_scaling_group_provider {
#     auto_scaling_group_arn = module.asg[each.key].autoscaling_group_arn
#     # auto_scaling_group_arn = aws_autoscaling_group.this[each.key].arn

#     managed_scaling {
#       maximum_scaling_step_size = each.value.maximum_scaling_step_size
#       minimum_scaling_step_size = each.value.minimum_scaling_step_size
#       target_capacity           = each.value.target_capacity
#       status                    = "ENABLED"
#       instance_warmup_period    = 300
#     }
#     managed_termination_protection = "DISABLED"
#   }
# }

# # Attach capacity providers to the cluster
# resource "aws_ecs_cluster_capacity_providers" "this" {
#   cluster_name       = aws_ecs_cluster.this.id
#   capacity_providers = var.deployment.use_fargate ? [for v in values(var.capacity_provider) : v.fargate] : [for cp in aws_ecs_capacity_provider.this : cp.name]
# }

# #---------------------
# #       Service
# #---------------------
# # TODO: https://github.com/OperationCode/operationcode_infra/blob/e288f0ba0e0eaef6c4c45ac842115d86b2286c3e/terraform/ecs.tf
# resource "aws_ecs_service" "this" {
#   name    = var.common_name
#   cluster = aws_ecs_cluster.this.id

#   desired_count           = var.service_task_desired_count
#   enable_ecs_managed_tags = true
#   scheduling_strategy     = "REPLICA"

#   # iam_role = var.deployment.use_fargate ? null : aws_iam_role.ecs_service.arn
#   iam_role    = aws_iam_role.ecs_service.arn
#   launch_type = null // no need with capacity providers

#   # network awsvpc
#   dynamic "network_configuration" {
#     for_each = var.deployment.use_fargate ? [1] : []
#     content {
#       subnets          = local.subnets
#       assign_public_ip = true // if private subnets, use NAT
#       security_groups  = [module.service_sg.security_group_id]
#     }
#   }

#   force_new_deployment = true
#   triggers = {
#     redeployment = timestamp() // redeploy the service on every apply
#   }

#   load_balancer {
#     target_group_arn = module.alb.target_group_arns[0] // one LB per target group
#     container_name   = var.common_name
#     container_port   = var.traffic.target_port
#   }

#   task_definition = aws_ecs_task_definition.service.arn

#   dynamic "capacity_provider_strategy" {
#     for_each = var.capacity_provider
#     iterator = cp
#     content {
#       base              = cp.value.base
#       weight            = cp.value.weight_percent
#       capacity_provider = var.deployment.use_fargate ? cp.value.fargate : aws_ecs_capacity_provider.this[cp.key].name
#     }
#   }

#   # service_registries # for route53

#   lifecycle {
#     ignore_changes = [desired_count] // CICD pipeline
#   }

#   tags = var.common_tags
# }

# module "service_sg" {
#   source  = "terraform-aws-modules/security-group/aws"
#   version = "5.0.0"

#   name        = "${var.common_name}-sg-service"
#   description = "Security group for Service within VPC"
#   vpc_id      = var.vpc.id

#   # ingress_with_cidr_blocks = [
#   #   {
#   #     from_port   = var.traffic.target_port
#   #     to_port     = var.traffic.target_port
#   #     protocol    = "tcp"
#   #     description = "Target port"
#   #     cidr_blocks = "0.0.0.0/0"
#   #   },
#   # ]
#   # computed_ingress_with_source_security_group_id = [
#   #   {
#   #     rule = "all-all"
#   #     # rule                     = "https-443-tcp"
#   #     source_security_group_id = module.alb_sg.security_group_id
#   #   }
#   # ]
#   # number_of_computed_ingress_with_source_security_group_id = 1
#   ingress_cidr_blocks = ["0.0.0.0/0"]
#   ingress_rules       = ["all-all"]
#   egress_rules        = ["all-all"]

#   tags = var.common_tags
# }

# data "aws_iam_policy_document" "ecs_assume_role" {
#   statement {
#     sid     = "ECSAssumeRole"
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["ecs.${local.dns_suffix}"]
#     }
#   }
# }

# # resource "aws_iam_policy" "ecs_service" {
# #   name = "${var.common_name}-ecs-service"

# #   description = "ECS service policy that allows Amazon ECS to make calls to your load balancer on your behalf"
# #   policy = jsonencode({
# #     Version = "2012-10-17"
# #     Statement = [
# #       {
# #         Action = [
# #           # "ec2:AuthorizeSecurityGroupIngress",
# #           # "ec2:Describe*",
# #           # "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
# #           # "elasticloadbalancing:DeregisterTargets",
# #           # "elasticloadbalancing:Describe*",
# #           # "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
# #           # "elasticloadbalancing:RegisterTargets"
# #           "ec2:*",
# #           "elasticloadbalancing:*",
# #           "autoscaling:*",
# #           "ecs:*",
# #           "ecr:*",
# #           "s3:*"
# #         ]
# #         Effect   = "Allow"
# #         Resource = "*",
# #       },
# #     ]
# #   })
# # }

# resource "aws_iam_role" "ecs_service" {
#   name = "${var.common_name}-ecs-service"

#   assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
#   # managed_policy_arns = [aws_iam_policy.ecs_service.arn]

#   tags = var.common_tags
# }
