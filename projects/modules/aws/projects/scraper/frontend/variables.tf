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

          container = object({
            name = string
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
          })
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
  })
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}
