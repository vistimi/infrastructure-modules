variable "aws" {
  type = object({
    level_key   = string
    level_value = string
    levels = optional(list(object({
      key   = string
      value = string
    })))
    groups = map(object({
      force_destroy         = optional(bool)
      create_admin_role     = optional(bool)
      create_poweruser_role = optional(bool)
      create_readonly_role  = optional(bool)
      attach_role_name      = optional(string)
      pw_length             = optional(number)
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
    repository_names  = list(string)
    store_environment = bool
  })

  validation {
    condition     = var.github.store_environment ? length(var.github.repository_names) > 0 : true
    error_message = "if store github is true, github repository names should not be empty"
  }
}
