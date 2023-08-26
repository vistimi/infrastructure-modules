variable "name_prefix" {
  description = "The name prefix that comes after the microservice name"
  type        = string
}

variable "name_suffix" {
  description = "The name suffix that comes after the microservice name"
  type        = string
}

variable "vpc" {
  type = object({
    id   = string
    tier = string
  })
}

variable "microservice" {
  type = object({
    route53 = optional(object({
      zones = list(object({
        name = string
      }))
      record = object({
        subdomain_name = string
        prefixes       = optional(list(string))
      })
    }))
    bucket_env = object({
      force_destroy = bool
      versioning    = bool
      file_path     = string
      file_key      = string
    })
    iam = object({
      scope       = string
      account_ids = optional(list(string))
      vpc_ids     = optional(list(string))
    })
    ecs = object({
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
        })
        base = optional(bool)
      }))
      task_definition = object({
        memory             = number
        memory_reservation = optional(number)
        cpu                = number
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
          name : string
          value : string
        })))
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
        processor     = string
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
  })
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}
