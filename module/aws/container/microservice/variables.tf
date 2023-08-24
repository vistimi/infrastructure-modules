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

variable "eks" {
  type = object({
  })
  default = null
}

variable "ecs" {
  type = object({
    service = object({
      deployment_type                    = string
      min_count                          = number
      desired_count                      = number
      max_count                          = number
      deployment_maximum_percent         = optional(number)
      deployment_minimum_healthy_percent = optional(number)
      deployment_circuit_breaker = optional(object({
        enable   = bool
        rollback = bool
      }))
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
    task_definition = object({
      volumes = optional(list(object({
        name = string
        host = object({
          sourcePath = string
        })
      })), [])

      memory             = optional(number)
      memory_reservation = optional(number)
      cpu                = number
      gpu                = optional(number)
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
      environment = optional(list(object({
        name  = string
        value = string
      })))
      resource_requirements = optional(list(object({
        type  = string
        value = string
      })))
      command                  = optional(list(string), [])
      entrypoint               = optional(list(string), [])
      health_check             = optional(any, {})
      readonly_root_filesystem = optional(bool)
      user                     = optional(string)
      volumes_from             = optional(list(any))
      working_directory        = optional(string)
      mount_points             = optional(list(any))
      linux_parameters         = optional(any, {})
    })
    fargate = optional(object({
      os           = string
      architecture = string
      capacity_provider = map(object({
        key    = string
        base   = optional(number)
        weight = optional(number)
      }))
    }))
    ec2 = optional(map(object({
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
        }))
      })
      capacity_provider = object({
        base                        = optional(number)
        weight                      = number
        target_capacity_cpu_percent = number
        maximum_scaling_step_size   = optional(number)
        minimum_scaling_step_size   = optional(number)
      })
    })))
  })
  default = null
}

resource "null_resource" "orchestrator" {
  lifecycle {
    precondition {
      condition     = length([for orchestrator in [var.ecs, var.eks] : true if orchestrator != null]) == 1
      error_message = "orchestrator must be either [ecs, eks]"
    }
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
