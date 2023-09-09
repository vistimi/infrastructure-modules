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
      subdomain_name = string
      prefixes       = optional(list(string))
    })
  })
  default = null
}

variable "bucket_env" {
  type = object({
    name          = string
    force_destroy = bool
    versioning    = bool
    file_path     = string
    file_key      = string
  })
  default = null
}

variable "iam" {
  type = object({
    scope        = string
    requires_mfa = optional(bool)
    mfa_age      = optional(number)
    account_ids  = optional(list(string))
    vpc_ids      = optional(list(string))
  })
}

variable "container" {
  type = object({
    group = object({
      deployment = object({
        min_size        = number
        max_size        = number
        desired_size    = number
        maximum_percent = optional(number)

        memory = optional(number)
        cpu    = number

        container = object({
          memory             = optional(number)
          memory_reservation = optional(number)
          cpu                = number
          gpu                = optional(number)
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
          command                  = optional(list(string), [])
          entrypoint               = optional(list(string), [])
          readonly_root_filesystem = optional(bool)
        })
      })
      ec2 = optional(object({
        key_name       = optional(string)
        instance_types = list(string)
        os             = string
        os_version     = string
        architecture   = string
        processor      = string

        capacities = optional(list(object({
          type   = optional(string, "ON_DEMAND")
          base   = optional(number)
          weight = optional(number, 1)
        })))
      }))
      fargate = optional(object({}))
    })
    traffics = list(object({
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
    eks = optional(object({
      cluster_version = string
    }))
    ecs = optional(object({
      service = optional(object({
        task = optional(object({
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
          container = object({
            health_check      = optional(any, {})
            user              = optional(string)
            volumes_from      = optional(list(any), [])
            working_directory = optional(string)
            mount_points      = optional(list(any), [])
            linux_parameters  = optional(any, {})
          })
        }))
      }))
    }))
  })

  # orchestrator
  validation {
    condition     = (var.container.ecs != null && var.container.eks == null) || (var.container.ecs == null && var.container.eks != null)
    error_message = "either ecs or eks should have a configuration"
  }

  # deplyoment type
  validation {
    condition     = (var.container.group.ec2 != null && var.container.group.fargate == null) || (var.container.group.ec2 == null && var.container.group.fargate != null)
    error_message = "either fargate or ec2 should have a configuration"
  }

  # traffic
  validation {
    condition     = length(var.container.traffics) > 0
    error_message = "traffic must have at least one element"
  }
  validation {
    condition     = length([for traffic in var.container.traffics : traffic.base if traffic.base == true || length(var.container.traffics) == 1]) == 1
    error_message = "traffics must have exactly one base or only one element (base not required)"
  }
  validation {
    condition     = length(distinct([for traffic in var.container.traffics : { listener = traffic.listener, target = traffic.target }])) == length(var.container.traffics)
    error_message = "traffics elements cannot be similar"
  }

  # traffic listeners
  validation {
    condition     = alltrue([for traffic in var.container.traffics : contains(["http", "https", "tcp"], traffic.listener.protocol)])
    error_message = "Listener protocol must be one of [http, https, tcp]"
  }
  validation {
    condition     = alltrue([for traffic in var.container.traffics : traffic.listener.protocol_version != null ? contains(["http1", "http2", "grpc"], traffic.listener.protocol_version) : true])
    error_message = "Listener protocol version must be one of [http1, http2, grpc] or null"
  }

  # traffic targets
  validation {
    condition     = alltrue([for traffic in var.container.traffics : contains(["http", "https", "tcp"], traffic.target.protocol)])
    error_message = "Target protocol must be one of [http, https, tcp]"
  }
  validation {
    condition     = alltrue([for traffic in var.container.traffics : traffic.target.protocol_version != null ? contains(["http1", "http2", "grpc"], traffic.target.protocol_version) : true])
    error_message = "Target protocol version must be one of [http1, http2, grpc] or null"
  }

  # docker
  validation {
    condition     = try(var.container.group.deployment.docker.registry.ecr.name != null, true)
    error_message = "docker registry name must not be empty if ecr is not specified"
  }

  validation {
    condition     = try(contains(["private", "public", "intra"], var.container.group.deployment.docker.registry.ecr.privacy), true)
    error_message = "docker repository privacy must be one of [public, private, intra]"
  }

  validation {
    condition     = try((var.container.group.deployment.docker.registry.ecr.privacy == "public" ? length(coalesce(var.container.group.deployment.docker.registry.ecr.public_alias, "")) > 0 : true), true)
    error_message = "docker repository alias need when repository privacy is `public`"
  }

  # # fargate
  # validation {
  #   condition     = contains(["linux"], var.fargate.os)
  #   error_message = "Fargate os must be one of [linux]"
  # }

  # validation {
  #   condition     = var.fargate.os == "linux" ? contains(["x86_64", "arm64"], var.fargate.architecture) : false
  #   error_message = "Fargate architecture must for one of linux:[x86_64, arm64]"
  # }

  # ec2 arch
  validation {
    condition     = length(distinct(var.container.group.ec2.instance_types)) == length(var.container.group.ec2.instance_types)
    error_message = "ec2 instance types must all be unique"
  }

  validation {
    condition     = contains(["inf", "gpu"], var.container.group.ec2.processor) ? length(var.container.group.ec2.instance_types) == 1 : true
    error_message = "ec2 inf/gpu instances must contain only one element, got ${jsonencode(var.container.group.ec2.instance_types)}"
  }

  # ec2 os
  validation {
    condition     = contains(["linux"], var.container.group.ec2.os)
    error_message = "EC2 os must be one of [linux]"
  }

  validation {
    condition     = var.container.group.ec2.os == "linux" ? contains(["2", "2023"], var.container.group.ec2.os_version) : false
    error_message = "EC2 os version must be one of linux:[2, 2023]"
  }
}

data "aws_ec2_instance_types" "region" {
  filter {
    name   = "instance-type"
    values = [for instance_type in var.container.group.ec2.instance_types : instance_type]
  }

  lifecycle {
    postcondition {
      condition     = sort(distinct([for instance_type in var.container.group.ec2.instance_types : instance_type])) == sort(distinct(self.instance_types))
      error_message = <<EOF
      ec2 instances type are not all available
      want::
      ${jsonencode(sort([for instance_type in var.container.group.ec2.instance_types : instance_type]))}
      got::
      ${jsonencode(sort(self.instance_types))}
EOF
    }
  }
}

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html
# https://aws.amazon.com/ec2/instance-types/
resource "null_resource" "ec2_architecture" {
  for_each = var.container.group.ec2 != null ? {
    for instance_type in var.container.group.ec2.instance_types :
    instance_type => {
      os              = var.container.group.ec2.os
      architecture    = var.container.group.ec2.architecture
      instance_type   = instance_type
      instance        = regex("^(?P<prefix>\\w+)\\.(?P<size>\\w+)$", instance_type)
      instance_family = try(one(regex("(mac|u-|dl|trn|inf|vt|Im|Is|hpc)", regex("^(?P<prefix>\\w+)\\.(?P<size>\\w+)$", instance_type).prefix)), substr(instance_type, 0, 1))
    }
  } : {}

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
      condition     = each.value.architecture == "gpu" ? var.container.group.container.gpu != null : true
      error_message = "EC2 gpu must have a task definition gpu number"
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
