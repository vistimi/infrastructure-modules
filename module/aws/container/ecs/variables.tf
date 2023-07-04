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
    memory               = number
    memory_reservation   = optional(number)
    cpu                  = number
    env_bucket_name      = string
    env_file_name        = string
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

variable "service" {
  type = object({
    use_fargate                        = bool
    task_min_count                     = number
    task_desired_count                 = number
    task_max_count                     = number
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
    os           = string
    architecture = string
    capacity_provider = optional(map(object({
      key    = string
      base   = optional(number)
      weight = optional(number)
    })), {})
  })
  nullable = false
  default = {
    os           = ""
    architecture = ""
  }
}

resource "null_resource" "fargate" {
  for_each = {
    for key, value in {} : key => {}
    if var.service.use_fargate
  }

  lifecycle {
    precondition {
      condition     = contains(["linux"], var.fargate.os)
      error_message = "Fargate os must be one of [linux]"
    }

    precondition {
      condition     = var.fargate.os == "linux" ? contains(["x64", "arm64"], var.fargate.architecture) : false
      error_message = "Fargate architecture must for one of linux:[x64, arm64]"
    }
  }
}

variable "fargate_os" {
  description = "Map to select the OS for Fargate"
  type        = map(string)

  default = {
    linux = "LINUX"
  }
}

variable "fargate_architecture" {
  description = "Map to select the architecture for Fargate"
  type        = map(string)

  default = {
    x64 = "X86_64"
  }
}



#--------------
# ASG
#--------------
variable "ec2" {
  type = map(object({
    user_data     = optional(string)
    instance_type = string
    os            = string
    os_version    = string
    architecture  = string
    use_spot      = bool
    key_name      = optional(string)
    asg = object({
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
      base                        = optional(number)
      weight                      = number
      target_capacity_cpu_percent = number
      maximum_scaling_step_size   = number
      minimum_scaling_step_size   = number
    })
  }))
  nullable = false
  default  = {}
}

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html
# https://aws.amazon.com/ec2/instance-types/
resource "null_resource" "ec2_architecture" {
  for_each = {
    for key, value in var.ec2 :
    key => {
      architecture    = value.architecture
      instance_type   = value.instance_type
      instance        = regex("^(?P<prefix>\\w+)\\.(?P<size>\\w+)?", value.instance_type)
      instance_family = try(regex("(mac|u-|dl|trn|inf|vt|Im|Is|hpc)", regex("^(?P<prefix>\\w+)\\.(?P<size>\\w+)?", value.instance_type)), substr(value.instance_type, 0, 1))
    }
    if !var.service.use_fargate
  }

  lifecycle {
    precondition {
      // TODO: add support for mac
      condition = each.value.architecture == "x64" ? contains(["t", "m", "c", "z", "u-", "x", "r", "dl", "trn", "f", "vt", "i", "d", "h", "hpc"], each.value.instance_family) && contains(["", "i"], substr(each.value.instance.prefix, length(each.value.instance_family) + 1, 1)) : (
        each.value.architecture == "amd64" ? contains(["t", "m", "c", "r", "i", "Im", "Is", "hpc"], each.value.instance_family) && contains(["a", "g"], substr(each.value.instance.prefix, length(each.value.instance_family) + 1, 1)) : (
          each.value.architecture == "gpu" ? contains(["p", "g"], each.value.instance_family) : (
            each.value.architecture == "inf" ? contains(["inf"], each.value.instance_family) : (
              false
            )
          )
        )
      )
      error_message = "EC2 instance config do not match, arch: ${each.value.architecture}, instance type ${each.value.instance_type}, instance family ${each.value.instance_family}, instance generation ${substr(each.value.instance.prefix, length(each.value.instance_family) + 0, 1)}, processor family ${substr(each.value.instance.prefix, length(each.value.instance_family) + 1, 1)}, additional capability ${substr(each.value.instance.prefix, length(each.value.instance_family) + 2, -1)}, instance size ${each.value.instance.size}"
    }
  }
}

// TODO: add support for mac and windows
resource "null_resource" "ec2_os" {
  for_each = {
    for key, value in var.ec2 :
    key => {
      os           = value.os
      os_version   = value.os_version
      architecture = value.architecture
    }
    if !var.service.use_fargate
  }

  lifecycle {
    precondition {
      condition     = contains(["linux"], each.value.os)
      error_message = "EC2 os must be one of [linux]"
    }

    precondition {
      condition     = each.value.os == "linux" ? contains(["2", "2023"], each.value.os_version) : false
      error_message = "EC2 os version must be one of linux:[2, 2023]"
    }

    precondition {
      condition     = each.value.os == "linux" ? contains(["x64", "arm64", "gpu", "inf"], each.value.architecture) : false
      error_message = "EC2 architecture must for one of linux:[x64, arm64, gpu, inf]"
    }
  }
}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/retrieve-ecs-optimized_AMI.html
variable "ami_ssm_name" {
  description = "Map to select an optimized ami for the correct architecture"
  type        = map(string)

  default = {
    amazon-linux-2-x64      = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
    amazon-linux-2-arm64    = "/aws/service/ecs/optimized-ami/amazon-linux-2/arm64/recommended/image_id"
    amazon-linux-2-gpu      = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended/image_id"
    amazon-linux-2-inf      = "/aws/service/ecs/optimized-ami/amazon-linux-2/inf/recommended/image_id"
    amazon-linux-2023-x64   = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
    amazon-linux-2023-arm64 = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id"
    # amazon-linux-2023-gpu   = "/aws/service/ecs/optimized-ami/amazon-linux-2023/gpu/recommended/image_id"
    amazon-linux-2023-inf = "/aws/service/ecs/optimized-ami/amazon-linux-2023/inf/recommended/image_id"
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
