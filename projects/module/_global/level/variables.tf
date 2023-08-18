variable "name_prefix" {
  description = "The name prefix that comes after the microservice name"
  type        = string
  default     = ""
}

variable "aws" {
  type = object({
    levels = optional(list(object({
      key   = string
      value = string
    })))
    groups = map(object({
      force_destroy = optional(bool)
      pw_length     = optional(number)
      project_names = optional(list(string), [])
      users = list(object({
        name = string
        statements = optional(list(object({
          sid       = optional(string)
          actions   = list(string)
          effect    = optional(string)
          resources = list(string)
          conditions = optional(list(object({
            test     = string
            variable = string
            values   = list(string)
          })), [])
        })), [])
      }))
      statements = optional(list(object({
        sid       = optional(string)
        actions   = list(string)
        effect    = optional(string)
        resources = list(string)
        conditions = optional(list(object({
          test     = string
          variable = string
          values   = list(string)
        })), [])
      })), [])
    }))
    statements = optional(list(object({
      sid       = optional(string)
      actions   = list(string)
      effect    = optional(string)
      resources = list(string)
      conditions = optional(list(object({
        test     = string
        variable = string
        values   = list(string)
      })), [])
    })), [])
    external_assume_role_arns = list(string)

    store_secrets = bool
    tags          = map(string)
  })

  validation {
    condition     = length(var.aws.groups) > 0
    error_message = "level must have at least one group"
  }
}

variable "github" {
  type = object({
    accesses = optional(list(object({
      owner = string
      name  = string
    })), [])
    repositories = optional(list(object({
      variables = optional(list(object({
        key   = string
        value = string
      })), [])
      secrets = optional(list(object({
        key   = string
        value = string
      })), [])
    })), [])
    store_environment = optional(bool, true)
  })
  default = {}
}
