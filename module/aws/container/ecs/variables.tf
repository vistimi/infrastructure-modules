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
      status_code       = optional(string)
    })
    base = optional(bool)
  }))
}

variable "ecs" {
  type = object({
    service = object({
      task = object({
        min_size                = number
        max_size                = number
        desired_size            = number
        maximum_percent         = optional(number)
        minimum_healthy_percent = optional(number)
        circuit_breaker = optional(object({
          enable   = bool
          rollback = bool
          }), {
          enable   = true
          rollback = true
        })

        volumes = optional(list(object({
          name = string
          host = object({
            sourcePath = string
          })
        })), [])
        memory = optional(number)
        cpu    = number

        containers = map(object({
          memory             = optional(number)
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
            registry = optional(object({
              name = optional(string)
              ecr = optional(object({
                privacy      = string
                public_alias = optional(string)
                account_id   = optional(string)
                region_name  = optional(string)
              }))
            }))
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
          linux_parameters         = optional(any, {})
        }))
      })
      ec2 = optional(object({
        key_name       = optional(string)
        instance_types = list(string)
        os             = string
        os_version     = string
        architecture   = string

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
        capacities = optional(list(object({
          type                        = optional(string, "ON_DEMAND")
          base                        = optional(number)
          weight                      = optional(number, 1)
          target_capacity_cpu_percent = optional(number, 66)
          maximum_scaling_step_size   = optional(number)
          minimum_scaling_step_size   = optional(number)
        })))
      }))
      fargate = optional(object({
        os           = string
        architecture = string

        capacities = optional(list(object({
          type                        = optional(string, "ON_DEMAND")
          base                        = optional(number)
          weight                      = optional(number, 1)
          target_capacity_cpu_percent = optional(number, 66)
        })))
      }))
    })
  })

  

  validation {
    condition     = flatten([for key_service, service in var.ecs.services : [for key_container, container in service.task_definition.containers : try(container.docker.registry.ecr.name, true)]])
    error_message = "docker registry name must not be empty if ecr is not specified"
  }

  validation {
    condition     = flatten([for key_service, service in var.ecs.services : [for key_container, container in service.task_definition.containers : try(contains(["private", "public", "intra"], container.docker.registry.ecr.privacy), true)]])
    error_message = "docker repository privacy must be one of [public, private, intra]"
  }

  validation {
    condition     = flatten([for key_service, service in var.ecs.services : [for key_container, container in service.task_definition.containers : try((container.docker.registry.ecr.privacy == "public" ? length(coalesce(container.docker.registry.ecr.public_alias, "")) > 0 : true), true)]])
    error_message = "docker repository alias need when repository privacy is `public`"
  }

  # # fargate
  # precondition {
  #   condition     = contains(["linux"], var.fargate.os)
  #   error_message = "Fargate os must be one of [linux]"
  # }

  # precondition {
  #   condition     = var.fargate.os == "linux" ? contains(["x86_64", "arm64"], var.fargate.architecture) : false
  #   error_message = "Fargate architecture must for one of linux:[x86_64, arm64]"
  # }

  # # ec2
  # postcondition {
  #   condition     = sort(distinct([for key, value in var.ec2 : value.instance_type])) == sort(distinct(self.instance_types))
  #   error_message = "ec2 instances type are not all available\nwant::\n ${jsonencode(sort([for key, value in var.ec2 : value.instance_type]))}\ngot::\n ${jsonencode(sort(self.instance_types))}"
  # }

  # postcondition {
  #   condition     = alltrue([for key, value in var.ec2 : contains(["inf", "gpu"], value.architecture)]) ? length(distinct([for key, value in var.ec2 : value.instance_type])) == 1 : true
  #   error_message = "ec2 inf/gpu instances must be the same, got ${jsonencode(sort([for key, value in var.ec2 : value.instance_type]))}"
  # }
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
      instance        = regex("^(?P<prefix>\\w+)\\.(?P<size>\\w+)$", value.instance_type)
      instance_family = try(one(regex("(mac|u-|dl|trn|inf|vt|Im|Is|hpc)", regex("^(?P<prefix>\\w+)\\.(?P<size>\\w+)$", value.instance_type).prefix)), substr(value.instance_type, 0, 1))
    }
    if var.service.deployment_type == "ec2"
  }

  lifecycle {
    precondition {
      condition     = each.value.os == "linux" ? contains(["x86_64", "arm64", "gpu", "inf"], each.value.architecture) : false
      error_message = "EC2 architecture must for one of linux:[x86_64, arm64, gpu, inf]"
    }

    precondition {
      // TODO: add support for mac
      condition = each.value.architecture == "x86_64" ? (
        contains(["t", "m", "c", "z", "u-", "x", "r", "dl", "trn", "f", "vt", "i", "d", "h", "hpc"], each.value.instance_family) && contains(["", "i"], substr(each.value.instance.prefix, length(each.value.instance_family) + 1, 1))
        ) : (
        each.value.architecture == "arm64" ? (
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
