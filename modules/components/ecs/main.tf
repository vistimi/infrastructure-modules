data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_subnets" "tier" {
  filter {
    name   = "vpc-id"
    values = [var.vpc.id]
  }
  tags = {
    Tier = var.vpc.tier
  }
}
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = var.ami_ssm_name[var.instance.ec2.ami_ssm_architecture]
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  dns_suffix = data.aws_partition.current.dns_suffix // amazonaws.com
  partition  = data.aws_partition.current.partition  // aws
  region     = data.aws_region.current.name
  subnets    = data.aws_subnets.tier.ids
  image_id   = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
}

// FIXME: only one instance with eIP attachement with EC2

#----------------
#     ALB
#----------------
# https://github.com/terraform-aws-modules/terraform-aws-alb/blob/master/examples/complete-alb/main.tf
# Cognito for authentication
module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name = var.common_name

  load_balancer_type = "application"

  vpc_id          = var.vpc.id
  subnets         = local.subnets
  security_groups = [module.alb_sg.security_group_id] // TODO: add vpc security group

  # access_logs = {
  #   bucket = module.s3_logs_alb.s3_bucket_id
  # }

  http_tcp_listeners = var.traffic.listener_protocol == "HTTP" ? [
    {
      port               = var.traffic.listener_port
      protocol           = var.traffic.listener_protocol
      target_group_index = 0
    },
  ] : []

  https_listeners = var.traffic.listener_protocol == "HTTPS" ? [
    {
      port     = var.traffic.listener_port
      protocol = var.traffic.listener_protocol
      # certificate_arn    = "arn:${local.partition}:iam::123456789012:server-certificate/test_cert-123456789012"
      target_group_index = 0
    }
  ] : []

  // forward listener to target
  target_groups = [
    {
      name             = var.common_name
      backend_protocol = var.traffic.target_protocol
      backend_port     = var.traffic.target_port
      target_type      = var.deployment.use_fargate ? "ip" : "instance" # "ip" non awsvpc network 
      health_check = {
        enabled             = true
        interval            = 10
        path                = var.traffic.health_check_path
        port                = var.traffic.target_port
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 5
        protocol            = var.traffic.target_protocol
        matcher             = "200-399"
      }
      # protocol_version = "HTTP1"
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
  vpc_id      = var.vpc.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  # ingress_rules       = ["http-80-tcp"] // TODO: use incoming port var
  ingress_with_cidr_blocks = [
    {
      from_port   = var.traffic.listener_port
      to_port     = var.traffic.listener_port
      protocol    = "tcp"
      description = "Listner port"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
  egress_rules = ["all-all"]

  tags = var.common_tags
}

# resource "aws_iam_role" "alb" {
#   name = "${var.common_name}-alb-logs"
#   tags = var.common_tags

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Action = "sts:AssumeRole",
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         },
#         Effect = "Allow",
#       },
#     ]
#   })
# }

# data "aws_iam_policy_document" "bucket_policy" {
#   statement {
#     principals {
#       type        = "AWS"
#       identifiers = [aws_iam_role.alb.arn]
#     }

#     actions = [
#       "s3:ListBucket",
#     ]

#     resources = [
#       "arn:${local.partition}:s3:::${var.common_name}-alb-logs",
#     ]
#   }
# }

# module "s3_logs_alb" {
#   source = "terraform-aws-modules/s3-bucket/aws"

#   bucket = "${var.common_name}-alb-logs"
#   # acl           = "log-delivery-write"
#   # acl           = "private"
#   force_destroy = true

#   versioning = {
#     status     = true
#     mfa_delete = false
#   }

#   # control_object_ownership = true
#   # object_ownership = "ObjectWriter"

#   control_object_ownership = true

#   attach_policy                         = true
#   policy                                = data.aws_iam_policy_document.bucket_policy.json
#   attach_elb_log_delivery_policy        = true # Required for ALB logs
#   attach_lb_log_delivery_policy         = true # Required for ALB/NLB logs
#   attach_access_log_delivery_policy     = true
#   attach_deny_insecure_transport_policy = true
#   attach_require_latest_tls_policy      = true

#   # access_log_delivery_policy_source_accounts = [data.aws_caller_identity.current.account_id]
#   # access_log_delivery_policy_source_buckets  = ["arn:${local.partition}:s3:::${var.bucket_env_name}"]

#   # logging = {
#   #   target_bucket = module.log_bucket.s3_bucket_id
#   #   target_prefix = "log/"
#   # }

#   # lifecycle_rule = [
#   #   # {
#   #   #   id      = "log"
#   #   #   enabled = true

#   #   #   # filter = {
#   #   #   #   tags = {
#   #   #   #     some    = "value"
#   #   #   #     another = "value2"
#   #   #   #   }
#   #   #   # }

#   #   #   transition = [
#   #   #     {
#   #   #       days          = 30
#   #   #       storage_class = "ONEZONE_IA"
#   #   #       }, {
#   #   #       days          = 60
#   #   #       storage_class = "GLACIER"
#   #   #     }
#   #   #   ]

#   #   #   #        expiration = {
#   #   #   #          days = 90
#   #   #   #          expired_object_delete_marker = true
#   #   #   #        }

#   #   #   #        noncurrent_version_expiration = {
#   #   #   #          newer_noncurrent_versions = 5
#   #   #   #          days = 30
#   #   #   #        }
#   #   # },
#   #   {
#   #     id                                     = "log1"
#   #     enabled                                = true
#   #     abort_incomplete_multipart_upload_days = 7

#   #     noncurrent_version_transition = [
#   #       {
#   #         days          = 30
#   #         storage_class = "STANDARD_IA"
#   #       },
#   #       {
#   #         days          = 60
#   #         storage_class = "ONEZONE_IA"
#   #       },
#   #       {
#   #         days          = 90
#   #         storage_class = "GLACIER"
#   #       },
#   #     ]

#   #     noncurrent_version_expiration = {
#   #       days = 300
#   #     }
#   #   },
#   #   # {
#   #   #   id      = "log2"
#   #   #   enabled = true

#   #   #   filter = {
#   #   #     prefix                   = "log1/"
#   #   #     object_size_greater_than = 200000
#   #   #     object_size_less_than    = 500000
#   #   #     tags = {
#   #   #       some    = "value"
#   #   #       another = "value2"
#   #   #     }
#   #   #   }

#   #   #   noncurrent_version_transition = [
#   #   #     {
#   #   #       days          = 30
#   #   #       storage_class = "STANDARD_IA"
#   #   #     },
#   #   #   ]

#   #   #   noncurrent_version_expiration = {
#   #   #     days = 300
#   #   #   }
#   #   # },
#   # ]

#   # intelligent_tiering = {
#   #   general = {
#   #     status = "Enabled"
#   #     filter = {
#   #       prefix = "/"
#   #       tags = {
#   #         Environment = "dev"
#   #       }
#   #     }
#   #     tiering = {
#   #       ARCHIVE_ACCESS = {
#   #         days = 180
#   #       }
#   #     }
#   #   },
#   #   documents = {
#   #     status = false
#   #     filter = {
#   #       prefix = "documents/"
#   #     }
#   #     tiering = {
#   #       ARCHIVE_ACCESS = {
#   #         days = 125
#   #       }
#   #       DEEP_ARCHIVE_ACCESS = {
#   #         days = 200
#   #       }
#   #     }
#   #   }
#   # }

#   # metric_configuration = [
#   #   {
#   #     name = "documents"
#   #     filter = {
#   #       prefix = "documents/"
#   #       tags = {
#   #         priority = "high"
#   #       }
#   #     }
#   #   },
#   #   {
#   #     name = "other"
#   #     filter = {
#   #       tags = {
#   #         production = "true"
#   #       }
#   #     }
#   #   },
#   #   {
#   #     name = "all"
#   #   }
#   # ]

#   tags = var.common_tags
# }

#---------------
#   Policies
#---------------

# Managed policies
data "aws_iam_policy" "aws_ec2_full_access_policy" {
  name = "AmazonEC2FullAccess"
}

data "aws_iam_policy" "aws_ecs_full_access_policy" {
  name = "AmazonECS_FullAccess"
}

data "aws_iam_policy" "aws_ecs_task_execution_role_policy" {
  name = "AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs_task_logs" {
  name = "${var.common_name}-ecs-task-container-logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy",
          "logs:CreateLogGroup"
        ]
        Effect   = "Allow"
        Resource = "*" # "arn:${local.partition}:logs:*:*:*" # "arn:${local.partition}:logs:*:*:log-group:/${local.log_prefix_ecs}/*",
      },
      {
        Action = [
          "logs:GetLogEvents",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*" # "arn:${local.partition}:logs:*:*:*" # "arn:${local.partition}:logs:*:*:log-group:/${local.log_prefix_ecs}/*:log-stream:*",
      },
    ]
  })
}

resource "aws_iam_policy" "ecr" {
  name = "${var.common_name}-ecr"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_task_s3_role_policy" {
  name = "${var.common_name}-ecs-task-container-s3-env"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Effect   = "Allow"
        Resource = "arn:${local.partition}:s3:::${var.task_definition.env_bucket_name}",
      },
      {
        Action   = ["s3:GetObject"]
        Effect   = "Allow"
        Resource = "arn:${local.partition}:s3:::${var.task_definition.env_bucket_name}/*",
      },
      # {
      #   "Action" : ["kms:GetPublicKey", "kms:GetKeyPolicy", "kms:DescribeKey"],
      #   "Effect" : "Allow",
      #   "Resource" : "*",
      # }
    ]
  })
}

resource "aws_iam_policy" "ecs_service" {
  name = "${var.common_name}-ecs-service"

  description = "ECS service policy that allows Amazon ECS to make calls to your load balancer on your behalf"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
          "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:Describe*",
          "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
          "elasticloadbalancing:RegisterTargets"
        ]
        Effect   = "Allow"
        Resource = "*",
      },
    ]
  })
}

# Assume policies
# data "aws_iam_policy_document" "ec2_instance_assume_role_policy" {
#   statement {
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["ec2.amazonaws.com"]
#     }
#   }
# }

data "aws_iam_policy_document" "ecs_task_assume_role_policy" {
  statement {
    sid     = "ECSTaskExecutionAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.${local.dns_suffix}"]
    }

    # # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html#create_task_iam_policy_and_role
    # condition {
    #   test     = "ArnLike"
    #   variable = "aws:SourceArn"
    #   values   = ["arn:${local.partition}:ecs:${local.region}:${local.account_id}:*"]
    # }

    # condition {
    #   test     = "StringEquals"
    #   variable = "aws:SourceAccount"
    #   values   = [local.account_id]
    # }
  }
}

data "aws_iam_policy_document" "ecs_service_assume_role_policy" {
  statement {
    sid     = "ECSServiceAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.${local.dns_suffix}"]
    }
  }
}

# Roles
# The Amazon Resource Name (ARN) of the task execution role that grants the Amazon ECS container agent permission to make AWS API calls on your behalf.
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.common_name}-ecs-execution"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
  managed_policy_arns = [
    data.aws_iam_policy.aws_ecs_task_execution_role_policy.arn,
    aws_iam_policy.ecr.arn,
    aws_iam_policy.ecs_task_s3_role_policy.arn,
    aws_iam_policy.ecs_task_logs.arn,
  ]

  tags = var.common_tags
}

# The short name or full Amazon Resource Name (ARN) of the AWS Identity and Access Management role that grants containers in the task permission to call AWS APIs on your behalf.
resource "aws_iam_role" "ecs_task_container_role" {
  name = "${var.common_name}-ecs-task-container"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
  managed_policy_arns = [
    data.aws_iam_policy.aws_ec2_full_access_policy.arn,
    data.aws_iam_policy.aws_ecs_full_access_policy.arn,
    aws_iam_policy.ecs_task_logs.arn,
  ]

  tags = var.common_tags
}

resource "aws_iam_role" "ecs_service_role" {
  name = "${var.common_name}-ecs-service"

  assume_role_policy = data.aws_iam_policy_document.ecs_service_assume_role_policy.json
  managed_policy_arns = [
    aws_iam_policy.ecs_service.arn,
    aws_iam_policy.ecs_task_logs.arn,
    aws_iam_policy.ecs_task_s3_role_policy.arn, // FIXME: remove me
  ]

  tags = var.common_tags
}

# ------------------------
#     Task definition
# ------------------------
resource "aws_ecs_task_definition" "service" {

  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_container_role.arn
  memory                   = var.task_definition.memory
  cpu                      = var.task_definition.cpu
  family                   = var.common_name
  requires_compatibilities = var.deployment.use_fargate ? ["FARGATE"] : ["EC2"]
  network_mode             = var.deployment.use_fargate ? "awsvpc" : "bridge"

  // only one container per instance
  container_definitions = jsonencode([
    {
      name = var.common_name
      environmentFiles : [
        {
          "value" : "arn:${local.partition}:s3:::${var.task_definition.env_bucket_name}/${var.task_definition.env_file_name}",
          "type" : "s3"
        }
      ]

      portMappings : var.task_definition.port_mapping
      memory            = var.task_definition.memory
      memoryReservation = var.task_definition.memory_reservation
      cpu               = var.task_definition.cpu
      logConfiguration : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : aws_cloudwatch_log_group.cluster.name
          "awslogs-region" : "${local.region}",
          "awslogs-stream-prefix" : "/${var.log.prefix}"
        }
      }

      // fargate AMI
      runtime_platform = var.deployment.use_fargate ? {
        "operatingSystemFamily" : var.instance.fargate.os,
        "cpuArchitecture" : var.instance.fargate.architecture
      } : null

      image     = "${local.account_id}.dkr.ecr.${local.region}.${local.dns_suffix}/${var.common_name}:${var.task_definition.registry_image_tag}"
      essential = true
    }
  ])
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/${var.log.prefix}/${var.common_name}"
  retention_in_days = var.log.retention_days

  tags = var.common_tags
}

#-----------------
#     Cluster
#-----------------
resource "aws_ecs_cluster" "this" {
  name = var.common_name

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.cluster.name
      }
    }
  }
}

#----------------------------
#     Capacity Providers
#----------------------------
# EC2 capacity providers
resource "aws_ecs_capacity_provider" "this" {
  for_each = {
    for key, value in var.capacity_provider :
    key => {
      name                      = "${var.common_name}-${key}"
      maximum_scaling_step_size = var.capacity_provider[key].scaling.maximum_scaling_step_size
      minimum_scaling_step_size = var.capacity_provider[key].scaling.minimum_scaling_step_size
      target_capacity           = var.capacity_provider[key].scaling.target_capacity_cpu_percent # utilization for the capacity provider
    }
    if !var.deployment.use_fargate
  }

  name = each.value.name

  auto_scaling_group_provider {
    auto_scaling_group_arn = module.asg[each.key].autoscaling_group_arn

    managed_scaling {
      maximum_scaling_step_size = each.value.maximum_scaling_step_size
      minimum_scaling_step_size = each.value.minimum_scaling_step_size
      target_capacity           = each.value.target_capacity
      status                    = "ENABLED"
      # instance_warmup_period    = 300
    }
    managed_termination_protection = "DISABLED"
  }
}

# Attach capacity providers to the cluster
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.id
  capacity_providers = var.deployment.use_fargate ? [for v in values(var.capacity_provider) : v.fargate] : [for cp in aws_ecs_capacity_provider.this : cp.name]
}

#---------------------
#       Service
#---------------------
resource "aws_ecs_service" "this" {
  name    = var.common_name
  cluster = aws_ecs_cluster.this.id

  desired_count           = var.service_task_desired_count
  enable_ecs_managed_tags = true

  # iam_role = var.deployment.use_fargate ? null : aws_iam_role.ecs_service_role.arn
  iam_role = null

  launch_type = var.deployment.use_fargate ? null : "EC2"

  # network awsvpc
  dynamic "network_configuration" {
    for_each = var.deployment.use_fargate ? [1] : []
    content {
      subnets          = local.subnets
      assign_public_ip = true // if private subnets, use NAT
      security_groups  = [module.service_sg.security_group_id]
    }
  }

  force_new_deployment = true
  triggers = {
    redeployment = timestamp() // redeploy the service on every apply
  }

  load_balancer {
    target_group_arn = module.alb.target_group_arns[0] // one LB per target group
    container_name   = var.common_name
    container_port   = var.traffic.target_port
  }

  task_definition = aws_ecs_task_definition.service.arn

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider
    iterator = cp
    content {
      base              = cp.value.base
      weight            = cp.value.weight_percent
      capacity_provider = var.deployment.use_fargate ? cp.value.fargate : aws_ecs_capacity_provider.this[cp.key].name
    }
  }

  lifecycle {
    ignore_changes = [desired_count] // CICD pipeline
  }

  tags = var.common_tags
}

module "service_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.common_name}-sg-service"
  description = "Security group for Service within VPC"
  vpc_id      = var.vpc.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_with_cidr_blocks = [
    {
      from_port   = var.traffic.target_port
      to_port     = var.traffic.target_port
      protocol    = "tcp"
      description = "Target port"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
  # computed_ingress_with_source_security_group_id = [
  #   {
  #     rule = "all-all"
  #     # rule                     = "https-443-tcp"
  #     source_security_group_id = module.alb_sg.security_group_id
  #   }
  # ]
  # number_of_computed_ingress_with_source_security_group_id = 1
  egress_rules = ["all-all"]

  tags = var.common_tags
}


#------------------------
#     EC2 autoscaler
#------------------------
# https://github.com/terraform-aws-modules/terraform-aws-autoscaling/blob/master/examples/complete/main.tf
module "asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  for_each = {
    for key, value in var.autoscaling_group :
    key => {
      name             = "${var.common_name}-${key}"
      min_size         = value.min_size
      desired_capacity = value.desired_size
      max_size         = value.max_size
      instance_market_options = value.use_spot ? {
        market_type = "spot"
      } : {}
      tag_specifications = value.use_spot ? [{
        resource_type = "spot-instances-request"
        tags          = merge(var.common_tags, { Name = "${var.common_name}-spot-instance-request" })
      }] : []
    }
    if !var.deployment.use_fargate
  }

  name             = each.value.name
  min_size         = each.value.min_size
  max_size         = each.value.max_size
  desired_capacity = each.value.desired_capacity
  tag_specifications = concat(each.value.tag_specifications, [{
    resource_type = "instance"
    tags          = merge(var.common_tags, { Name = "${var.common_name}-instance" })
  }])
  instance_market_options = each.value.instance_market_options
  instance_type           = var.instance.ec2.instance_type
  image_id                = local.image_id

  use_name_prefix = false
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

  # iam_instance_profile_arn = aws_iam_instance_profile.ssm.arn // FIXME: try using ssm role
  create_iam_instance_profile = true
  iam_role_name               = var.common_name
  iam_role_path               = "/ec2/"
  iam_role_description        = "ASG role for ${var.common_name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:${local.partition}:iam::${local.partition}:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    AmazonSSMManagedInstanceCore        = "arn:${local.partition}:iam::${local.partition}:policy/AmazonSSMManagedInstanceCore"
    Logs                                = aws_iam_policy.ecs_task_logs.arn           // FIXME: remove
    S3                                  = aws_iam_policy.ecs_task_s3_role_policy.arn // FIXME: remove
  }
  iam_role_tags = var.common_tags

  vpc_zone_identifier     = local.subnets
  health_check_type       = "EC2" // FIXME: try "ELB" but shouldn't work
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
        "group"         = each.key,
        "instance_type" = var.instance.ec2.instance_type
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
        "instance_type" = var.instance.ec2.instance_type
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
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.common_name}-sg-as"
  description = "Autoscaling group security group" # "Security group with HTTP port open for everyone, and HTTPS open just for the default security group"
  vpc_id      = var.vpc.id

  ingress_cidr_blocks = ["0.0.0.0/0"]

  // only accept incoming traffic from load balancer 
  computed_ingress_with_source_security_group_id = [
    {
      rule = "all-all"
      # rule                     = "https-443-tcp"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1
  egress_rules                                             = ["all-all"]

  tags = var.common_tags
}

# resource "aws_iam_instance_profile" "ssm" {
#   name = "${var.common_name}-ssm"
#   role = aws_iam_role.ssm.name
#   tags = var.common_tags
# }

# resource "aws_iam_role_policy_attachment" "ssm" {
#   for_each = toset([
#     # "arn:${local.partition}:iam::${local.partition}:policy/AmazonEC2FullAccess", 
#     # "arn:${local.partition}:iam::${local.partition}:policy/AmazonS3FullAccess",
#     "arn:${local.partition}:iam::${local.partition}:policy/service-role/AmazonEC2RoleforSSM",
#     "arn:${local.partition}:iam::${local.partition}:policy/CloudWatchAgentServerPolicy"
#   ])

#   role       = aws_iam_role.ssm.name
#   policy_arn = each.value
# }

# resource "aws_iam_role_policy" "ssm" {
#   name = "EC2-Inline-Policy"
#   role = aws_iam_role.ssm.id
#   policy = jsonencode(
#     {
#       "Version" : "2012-10-17",
#       "Statement" : [
#         {
#           "Effect" : "Allow",
#           "Action" : [
#             "ssm:GetParameter"
#           ],
#           "Resource" : "*"
#         }
#       ]
#     }
#   )
# }

# resource "aws_iam_role" "ssm" {
#   name = "${var.common_name}-ssm"
#   tags = var.common_tags

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Action = "sts:AssumeRole",
#         Principal = {
#           Service = "ec2.${local.dns_suffix}"
#         }
#         Effect = "Allow"
#       },
#       # {
#       #   Action = [
#       #     "logs:CreateLogStream",
#       #     "logs:PutLogEvents",
#       #     "logs:DescribeLogStreams",
#       #     "logs:PutRetentionPolicy",
#       #     "logs:CreateLogGroup"
#       #   ]
#       #   Effect   = "Allow"
#       #   Resource = "arn:${local.partition}:logs:*:*:*" # "arn:${local.partition}:logs:*:*:log-group:/${local.log_prefix_ecs}/*",
#       # },
#       # {
#       #   Action = [
#       #     "logs:GetLogEvents",
#       #     "logs:PutLogEvents"
#       #   ]
#       #   Effect   = "Allow"
#       #   Resource = "arn:${local.partition}:logs:*:*:*" # "arn:${local.partition}:logs:*:*:log-group:/${local.log_prefix_ecs}/*:log-stream:*",
#       # },
#     ]
#   })
# }

# module "s3_logs_instance" {
#   source = "terraform-aws-modules/s3-bucket/aws"

#   bucket = "${var.common_name}-instance-logs"
#   # acl    = "private"
#   acl = "log-delivery-write"

#   versioning = {
#     enabled = false
#   }

#   # control_object_ownership = true
#   # object_ownership = "ObjectWriter"

#   force_destroy = true

#   tags = merge(var.common_tags)
# }

# resource "aws_ssm_parameter" "cw_agent" {
#   description = "Cloudwatch agent config to configure custom log"
#   name        = "${var.common_name}-cw-agent"
#   type        = "String"
#   value       = file("cw_agent_config.json")
# }
