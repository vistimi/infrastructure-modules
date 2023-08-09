variable "name" {
  description = "The common part of the name used for all resources"
  type        = string
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

variable "vpc" {
  type = object({
    id   = string
    tier = string
  })
}

resource "null_resource" "deployment_type" {
  lifecycle {
    precondition {
      condition     = contains(["fargate", "ec2"], var.service.deployment_type)
      error_message = "EC2 deployment type must be one of [fargate, ec2]"
    }
  }
}

#--------------
# ELB & ECS
#--------------
variable "route53" {
  type = object({
    zones = list(object({
      name = string
    }))
    record = object({
      prefixes       = optional(list(string))
      subdomain_name = string
    })
  })
  default = null
}

# https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html#target-group-protocol-version
variable "traffics" {
  type = list(object({
    listener = object({
      protocol         = string
      port             = optional(number)
      protocol_version = optional(string)
    })
    target = object({
      protocol          = string
      port              = number
      protocol_version  = optional(string)
      health_check_path = optional(string)
    })
    base = optional(bool)
  }))

  validation {
    condition     = length(var.traffics) > 0
    error_message = "traffic must have at least one element"
  }

  validation {
    condition     = length([for traffic in var.traffics : traffic.base if traffic.base != null]) <= 1
    error_message = "traffic must at most one base"
  }
}

resource "null_resource" "listener" {

  for_each = {
    for traffic in var.traffics :
    join("-", compact([traffic.listener.protocol, traffic.listener.port])) => traffic.listener
  }

  lifecycle {
    precondition {
      condition     = contains(["http", "https", "tcp"], each.value.protocol)
      error_message = "Listener protocol must be one of [http, https, tcp]"
    }
    precondition {
      condition     = each.value.protocol_version != null ? contains(["http", "http2", "grpc"], each.value.protocol_version) : true
      error_message = "Listener protocol version must be one of [http, http2, grpc] or null"
    }
  }
}

resource "null_resource" "target" {

  for_each = {
    for traffic in var.traffics :
    join("-", compact([traffic.target.protocol, traffic.target.port])) => traffic.target
  }

  lifecycle {
    precondition {
      condition     = contains(["http", "https", "tcp"], each.value.protocol)
      error_message = "Target protocol must be one of [http, https, tcp]"
    }
    precondition {
      condition     = each.value.protocol_version != null ? contains(["http", "http2", "grpc"], each.value.protocol_version) : true
      error_message = "Target protocol version must be one of [http, http2, grpc] or null"
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
    prefix         = "ecs"
  }
}

# inference_accelerators = optional(list(object({
# deviceName = string
# deviceType = string
# })), [])
variable "task_definition" {
  type = object({
    memory             = number
    memory_reservation = optional(number)
    cpu                = number
    gpu                = optional(number)
    env_file = optional(object({
      bucket_name = string
      file_name   = string
    }))
    environment = optional(list(object({
      name  = string
      value = string
    })), [])
    docker = object({
      registry = object({
        name = optional(string)
        ecr = optional(object({
          privacy      = string
          public_alias = optional(string)
          account_id   = optional(string)
          region_name  = optional(string)
        }))
      })
      repository = object({
        name = string
      })
      image = optional(object({
        tag = string
      }))
    })
    resource_requirements = optional(list(object({
      type  = string
      value = string
    })), [])
    command                  = optional(list(string), [])
    entrypoint               = optional(list(string), [])
    health_check             = optional(any, {})
    readonly_root_filesystem = optional(bool)
    user                     = optional(string)
    volumes_from             = optional(list(any), [])
    working_directory        = optional(string)
    mount_points             = optional(list(any), [])
  })

  validation {
    condition     = try(var.task_definition.docker.registry.ecr.name != null, true)
    error_message = "docker registry name must not be empty if ecr is not specified"
  }

  validation {
    condition     = try(contains(["public", "private"], var.task_definition.docker.registry.ecr.privacy), true)
    error_message = "docker repository privacy must be one of [public, private]"
  }

  validation {
    condition     = try((var.task_definition.docker.registry.ecr.privacy == "public" ? length(coalesce(var.task_definition.docker.registry.ecr.public_alias, "")) > 0 : true), true)
    error_message = "docker repository alias need when repository privacy is `public`"
  }
}

variable "service" {
  type = object({
    deployment_type                    = string
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
    if var.service.deployment_type == "fargate"
  }

  lifecycle {
    precondition {
      condition     = contains(["linux"], var.fargate.os)
      error_message = "Fargate os must be one of [linux]"
    }

    precondition {
      condition     = var.fargate.os == "linux" ? contains(["x86_64", "arm_64"], var.fargate.architecture) : false
      error_message = "Fargate architecture must for one of linux:[x86_64, arm_64]"
    }
  }
}

#--------------
#   ASG
#--------------
# TODO: remove arch because not needed
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
      maximum_scaling_step_size   = optional(number)
      minimum_scaling_step_size   = optional(number)
    })
  }))
  nullable = false
  default  = {}

  # validation {
  #   condition     = [for key, value in var.ec2 : contains(["ecs-optimized", "deep-learning"], value.ami_type)]
  #   error_message = "ec2 ami_type should be in [ecs-optimized, deep-learning]"
  # }
}

data "aws_ec2_instance_types" "region" {
  filter {
    name   = "instance-type"
    values = [for key, value in var.ec2 : value.instance_type]
  }

  lifecycle {
    postcondition {
      condition     = sort(distinct([for key, value in var.ec2 : value.instance_type])) == sort(distinct(self.instance_types))
      error_message = "ec2 instances type are not all available\nwant::\n ${jsonencode(sort([for key, value in var.ec2 : value.instance_type]))}\ngot::\n ${jsonencode(sort(self.instance_types))}"
    }
  }
}

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html
# https://aws.amazon.com/ec2/instance-types/
resource "null_resource" "ec2_architecture" {
  for_each = {
    for key, value in var.ec2 :
    key => {
      os              = value.os
      architecture    = value.architecture
      instance_type   = value.instance_type
      instance        = regex("^(?P<prefix>\\w+)\\.(?P<size>\\w+)?", value.instance_type)
      instance_family = try(regex("(mac|u-|dl|trn|inf|vt|Im|Is|hpc)", regex("^(?P<prefix>\\w+)\\.(?P<size>\\w+)?", value.instance_type)), substr(value.instance_type, 0, 1))
    }
    if var.service.deployment_type == "ec2"
  }

  lifecycle {
    precondition {
      condition     = each.value.os == "linux" ? contains(["x86_64", "arm_64", "gpu", "inf"], each.value.architecture) : false
      error_message = "EC2 architecture must for one of linux:[x86_64, arm_64, gpu, inf]"
    }

    precondition {
      // TODO: add support for mac
      condition = each.value.architecture == "x86_64" ? (
        contains(["t", "m", "c", "z", "u-", "x", "r", "dl", "trn", "f", "vt", "i", "d", "h", "hpc"], each.value.instance_family) && contains(["", "i"], substr(each.value.instance.prefix, length(each.value.instance_family) + 1, 1))
        ) : (
        each.value.architecture == "arm_64" ? (
          contains(["t", "m", "c", "r", "i", "Im", "Is", "hpc"], each.value.instance_family) && contains(["a", "g"], substr(each.value.instance.prefix, length(each.value.instance_family) + 1, 1))
          ) : (
          each.value.architecture == "gpu" ? contains(["p", "g"], each.value.instance_family) : (
            each.value.architecture == "inf" ? contains(["inf"], each.value.instance_family) : (false)
          )
        )
      )
      error_message = "EC2 instance config do not match, arch: ${each.value.architecture}, instance type ${each.value.instance_type}, instance family ${each.value.instance_family}, instance generation ${substr(each.value.instance.prefix, length(each.value.instance_family) + 0, 1)}, processor family ${substr(each.value.instance.prefix, length(each.value.instance_family) + 1, 1)}, additional capability ${substr(each.value.instance.prefix, length(each.value.instance_family) + 2, -1)}, instance size ${each.value.instance.size}"
    }

    precondition {
      condition     = each.value.architecture == "gpu" ? var.task_definition.gpu != null : true
      error_message = "EC2 gpu must have a task definition gpu number"
    }
  }
}

// TODO: add support for mac and windows
resource "null_resource" "ec2_os" {
  for_each = {
    for key, value in var.ec2 :
    key => {
      os         = value.os
      os_version = value.os_version
    }
    if var.service.deployment_type == "ec2"
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
