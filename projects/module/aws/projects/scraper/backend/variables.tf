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
    container = object({
      group = object({
        name = string
        deployment = object({
          min_size        = number
          max_size        = number
          desired_size    = number
          maximum_percent = optional(number)

          memory = optional(number)
          cpu    = number

          container = object({
            name               = string
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
  })
}

#--------------
# Dynamodb
#--------------

variable "dynamodb_tables" {
  description = "The mapping of the DynamoDB tables"
  type = list(object({
    name                 = string
    primary_key_name     = string
    primary_key_type     = string
    sort_key_name        = string
    sort_key_type        = string
    predictable_workload = bool
    predictable_capacity = optional(object({
      autoscaling = bool
      read = optional(object({
        capacity           = number
        scale_in_cooldown  = number
        scale_out_cooldown = number
        target_value       = number
        max_capacity       = number
      }))
      write = optional(object({
        capacity           = number
        scale_in_cooldown  = number
        scale_out_cooldown = number
        target_value       = number
        max_capacity       = number
      }))
    }))
  }))
}

#--------------
# Pictures
#--------------

variable "bucket_picture" {
  type = object({
    name          = string
    force_destroy = bool
    versioning    = bool
  })
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}
