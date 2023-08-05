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
        })))
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
      })))
    }))
    statements = list(object({
      sid       = optional(string)
      actions   = list(string)
      effect    = optional(string)
      resources = list(string)
      conditions = optional(list(object({
        test     = string
        variable = string
        values   = list(string)
      })), [])
    }))
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
    repositories = optional(list(object({
      owner = string
      name  = string
    })), [])
    variables = optional(list(object({
      key   = string
      value = string
    })), [])
    store_environment = bool
  })

  validation {
    condition     = var.github.store_environment ? length(var.github.repositories) > 0 : true
    error_message = "if store github is true, github repositories should not be empty"
  }
}
