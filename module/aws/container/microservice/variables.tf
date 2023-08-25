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

variable "container" {
  type = object({
    group = object({
      deployment = object({
        min_size        = number
        max_size        = number
        desired_size    = number
        maximum_percent = optional(number)
      })
      ec2 = optional(object({
        key_name       = optional(string)
        instance_types = list(string)
        os             = string
        os_version     = string
        architecture   = string

        capacities = optional(list(object({
          type = optional(string, "ON_DEMAND")
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
    ecs = optional(object({}))
  })

  # orchestrator
  validation {
    condition     = (var.container.group.ec2 != null && var.container.group.fargate == null) || (var.container.group.ec2 == null && var.container.group.fargate != null)
    error_message = "either fargate or ec2 should have a configurations"
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
    condition     = alltrue([for traffic in var.container.traffics : traffic.listener.protocol_version != null ? contains(["http", "http2", "grpc"], traffic.listener.protocol_version) : true])
    error_message = "Listener protocol version must be one of [http, http2, grpc] or null"
  }

  # traffic targets
  validation {
    condition     = alltrue([for traffic in var.container.traffics : contains(["http", "https", "tcp"], traffic.target.protocol)])
    error_message = "Target protocol must be one of [http, https, tcp]"
  }
  validation {
    condition     = alltrue([for traffic in var.container.traffics : traffic.target.protocol_version != null ? contains(["http", "http2", "grpc"], traffic.target.protocol_version) : true])
    error_message = "Target protocol version must be one of [http, http2, grpc] or null"
  }
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
