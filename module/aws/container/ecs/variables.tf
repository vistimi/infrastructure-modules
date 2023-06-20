variable "common_name" {
  description = "The common part of the name used for all resources"
  type        = string
}

variable "common_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

variable "vpc" {
  type = object({
    id                 = string
    security_group_ids = list(string)
    tier               = string
  })
}

#--------------
# ELB & ECS
#--------------

# https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html#target-group-protocol-version
variable "traffic" {
  type = object({
    listener_port             = number
    listener_protocol         = string
    listener_protocol_version = string
    target_port               = number
    target_protocol           = string
    target_protocol_version   = string
    health_check_path         = optional(string, "/")
  })
}

resource "null_resource" "listener" {
  lifecycle {
    precondition {
      condition     = contains(["http", "https"], var.traffic.listener_protocol)
      error_message = "Listener protocol must be one of [http, http2, grpc]"
    }
    precondition {
      condition     = contains(["http", "http2", "grpc"], var.traffic.listener_protocol_version)
      error_message = "Listener protocol version must be one of [http, http2, grpc]"
    }
    precondition {
      condition     = contains(["http", "https"], var.traffic.target_protocol)
      error_message = "Target protocol must be one of [http, http2, grpc]"
    }
    precondition {
      condition     = contains(["http", "http2", "grpc"], var.traffic.target_protocol_version)
      error_message = "Target protocol version must be one of [http, http2, grpc]"
    }
  }
}

#--------------
# ECS
#--------------

variable "log" {
  type = object({
    retention_days = number
    prefix         = optional(string)
  })
  default = {
    retention_days = 30
    prefix         = "aws/ecs"
  }
}

# https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-ecs-taskdefinition-tmpfs.html#aws-properties-ecs-taskdefinition-tmpfs-properties
variable "task_definition" {
  type = object({
    memory             = number
    memory_reservation = optional(number)
    cpu                = number
    env_bucket_name    = string
    env_file_name      = string
    repository_name      = string
    repository_image_tag = string
    tmpfs = optional(object({
      ContainerPath : optional(string),
      MountOptions : optional(list(string)),
      Size : number,
    }), null)
    environment = optional(list(object({
      name : string
      value : string
    })), [])
  })
}

variable "capacity_provider" {
  description = "only one base for all capacity providers to define which are the necessary instances. The map key must be matching between capacity_providers/autoscaling. Either use fargate or ec2 based on the deployment configuration. "
  type = map(object({
    base           = optional(number)
    weight_percent = optional(number, 50)
  }))
}

variable "service" {
  type = object({
    use_fargate                        = bool
    task_desired_count                 = number
    deployment_maximum_percent         = optional(number)
    deployment_minimum_healthy_percent = optional(number)
    deployment_circuit_breaker = optional(object({
      enable   = bool
      rollback = bool
      }), {
      enable   = true
      rollback = true
    })
  })
}

variable "fargate" {
  type = object({
    os                = string
    architecture      = string
    capacity_provider = map(string)
  })
  default = {
    os                = "LINUX"
    architecture      = "X86_64"
    capacity_provider = {}
  }
}

#--------------
# ASG
#--------------
variable "ec2" {
  type = map(object({
    user_data            = optional(string)
    instance_type        = string
    ami_ssm_architecture = string
    use_spot             = bool
    key_name             = optional(string)
    asg = object({
      min_size     = number
      desired_size = number
      max_size     = number
      instance_refresh = optional(object({
        strategy = string
        preferences = optional(object({
          checkpoint_delay       = optional(number)
          checkpoint_percentages = optional(list(number))
          instance_warmup        = optional(number)
          min_healthy_percentage = optional(number)
          skip_matching          = optional(bool)
          auto_rollback          = optional(bool)
        }))
        triggers = optional(list(string))
        }), {
        strategy = "Rolling"
        preferences = {
          min_healthy_percentage = 66
        }
      })
    })
    capacity_provider = object({
      target_capacity_cpu_percent = number
      maximum_scaling_step_size   = number
      minimum_scaling_step_size   = number
    })
  }))
}

variable "ami_ssm_name" {
  description = "Map to select an optimized ami for the correct architecture"
  type        = map(string)

  default = {
    amazon-linux-2          = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
    amazon-linux-2-arm64    = "/aws/service/ecs/optimized-ami/amazon-linux-2/arm64/recommended"
    amazon-linux-2-gpu      = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended"
    amazon-linux-2-inf      = "/aws/service/ecs/optimized-ami/amazon-linux-2/inf/recommended"
    amazon-linux-2023       = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended"
    amazon-linux-2023-arm64 = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended"
    # amazon-linux-2023-gpu   = "/aws/service/ecs/optimized-ami/amazon-linux-2023/gpu/recommended"
    amazon-linux-2023-inf = "/aws/service/ecs/optimized-ami/amazon-linux-2023/inf/recommended"
  }
}

# ebs_device_map = {
#   amazon2       = "/dev/sdf"
#   amazon2023    = "/dev/sdf"
#   amazoneks     = "/dev/sdf"
#   amazonecs     = "/dev/xvdcz"
#   rhel7         = "/dev/sdf"
#   rhel8         = "/dev/sdf"
#   centos7       = "/dev/sdf"
#   ubuntu18      = "/dev/sdf"
#   ubuntu20      = "/dev/sdf"
#   debian10      = "/dev/sdf"
#   debian11      = "/dev/sdf"
#   windows2012r2 = "xvdf"
#   windows2016   = "xvdf"
#   windows2019   = "xvdf"
#   windows2022   = "xvdf"
# }

# root_device_map = {
#   amazon2       = "/dev/xvda"
#   amazon2023    = "/dev/xvda"
#   amazoneks     = "/dev/xvda"
#   amazonecs     = "/dev/xvda"
#   rhel7         = "/dev/sda1"
#   rhel8         = "/dev/sda1"
#   centos7       = "/dev/sda1"
#   ubuntu18      = "/dev/sda1"
#   ubuntu20      = "/dev/sda1"
#   windows2012r2 = "/dev/sda1"
#   windows2016   = "/dev/sda1"
#   windows2019   = "/dev/sda1"
#   windows2022   = "/dev/sda1"
#   debian10      = "/dev/sda1"
#   debian11      = "/dev/sda1"
# }
