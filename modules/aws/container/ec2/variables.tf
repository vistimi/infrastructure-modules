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
  nullable = false

  # traffic
  validation {
    condition     = length(var.traffics) > 0
    error_message = "traffic must have at least one element"
  }
  validation {
    condition     = length([for traffic in var.traffics : traffic.base if traffic.base == true || length(var.traffics) == 1]) == 1
    error_message = "traffics must have exactly one base or only one element (base not required)"
  }
  validation {
    condition     = length(distinct([for traffic in var.traffics : { listener = traffic.listener, target = traffic.target }])) == length(var.traffics)
    error_message = "traffics elements cannot be similar"
  }

  # traffic listeners
  validation {
    condition     = alltrue([for traffic in var.traffics : contains(["http", "https", "tcp"], traffic.listener.protocol)])
    error_message = "Listener protocol must be one of [http, https, tcp]"
  }
  validation {
    condition     = alltrue([for traffic in var.traffics : traffic.listener.protocol_version != null ? contains(["http1", "http2", "grpc"], traffic.listener.protocol_version) : true])
    error_message = "Listener protocol version must be one of [http1, http2, grpc] or null"
  }

  # traffic targets
  validation {
    condition     = alltrue([for traffic in var.traffics : contains(["http", "https", "tcp"], traffic.target.protocol)])
    error_message = "Target protocol must be one of [http, https, tcp]"
  }
  validation {
    condition     = alltrue([for traffic in var.traffics : traffic.target.protocol_version != null ? contains(["http1", "http2", "grpc"], traffic.target.protocol_version) : true])
    error_message = "Target protocol version must be one of [http1, http2, grpc] or null"
  }
}

variable "orchestrator" {
  type = object({
    group = object({
      name = string
      deployment = object({
        min_size        = number
        max_size        = number
        desired_size    = number
        maximum_percent = optional(number)

        containers = list(object({
          name        = string
          base        = optional(bool)
          cpu         = optional(number)
          memory      = optional(number)
          memory_reservation = optional(number, 50)
          devices_idx = optional(list(number))
          environments = optional(list(object({
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
          user                     = optional(string)
          mount_points = optional(list(object({
            s3 = optional(object({
              name = string
            }))
            container_path = string
            read_only      = optional(bool)
          })))
        }))
      })
      ec2 = optional(object({
        key_name       = optional(string)
        instance_types = list(string)
        os             = string
        os_version     = string

        capacities = optional(list(object({
          type   = optional(string, "ON_DEMAND")
          base   = optional(number)
          weight = optional(number, 1)
        })))
      }))
      fargate = optional(object({
        os           = string
        architecture = string

        capacities = optional(list(object({
          type   = optional(string, "ON_DEMAND")
          base   = optional(number)
          weight = optional(number, 1)
        })))
      }))
    })
    eks = optional(object({
      cluster_version = string
    }))
    ecs = optional(object({}))
  })

  # orchestrator
  validation {
    condition     = (var.orchestrator.ecs != null && var.orchestrator.eks == null) || (var.orchestrator.ecs == null && var.orchestrator.eks != null)
    error_message = "either ecs or eks should have a configuration"
  }

  # deployment type
  validation {
    condition     = (var.orchestrator.group.ec2 != null && var.orchestrator.group.fargate == null) || (var.orchestrator.group.ec2 == null && var.orchestrator.group.fargate != null)
    error_message = "either fargate or ec2 should have a configuration"
  }

  # container
  validation {
    condition     = alltrue([for container in var.orchestrator.group.deployment.containers : try(container.docker.registry.ecr.name != null, true)])
    error_message = "docker registry name must not be empty if ecr is not specified"
  }

  validation {
    condition     = alltrue([for container in var.orchestrator.group.deployment.containers : try(contains(["private", "public"], container.docker.registry.ecr.privacy), true)])
    error_message = "docker repository privacy must be one of [public, private]"
  }

  validation {
    condition     = alltrue([for container in var.orchestrator.group.deployment.containers : try((container.docker.registry.ecr.privacy == "public" ? length(coalesce(container.docker.registry.ecr.public_alias, "")) > 0 : true), true)])
    error_message = "docker repository alias need when repository privacy is `public`"
  }

  validation {
    condition     = length(compact([for container in var.orchestrator.group.deployment.containers : container.base])) == 1 || length(var.orchestrator.group.deployment.containers) == 1
    error_message = "containers must have one base or be unique"
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

  # ec2 instance_type
  validation {
    condition     = length(distinct(var.orchestrator.group.ec2.instance_types)) == length(var.orchestrator.group.ec2.instance_types)
    error_message = "ec2 instance types must all be unique"
  }

  # ec2 os
  validation {
    condition     = contains(["linux"], var.orchestrator.group.ec2.os)
    error_message = "EC2 os must be one of [linux]"
  }

  validation {
    condition     = var.orchestrator.group.ec2.os == "linux" ? contains(["2", "2023"], var.orchestrator.group.ec2.os_version) : false
    error_message = "EC2 os version must be one of linux:[2, 2023]"
  }
}

data "aws_ec2_instance_types" "region" {
  filter {
    name   = "instance-type"
    values = [for instance_type in var.orchestrator.group.ec2.instance_types : instance_type]
  }

  lifecycle {
    postcondition {
      condition     = sort(distinct([for instance_type in var.orchestrator.group.ec2.instance_types : instance_type])) == sort(distinct(self.instance_types))
      error_message = <<EOF
ec2 instances type are not all available
want::
${jsonencode(sort([for instance_type in var.orchestrator.group.ec2.instance_types : instance_type]))}
got::
${jsonencode(sort(self.instance_types))}
EOF
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
