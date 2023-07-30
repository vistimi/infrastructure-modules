variable "levels" {
  description = "Levels of hierarchy before this level, order matters!"
  type = list(object({
    key   = string
    value = string
  }))
  nullable = false
  default  = []

  validation {
    condition     = alltrue([for level in var.levels : contains(["organization", "team"], level.key)])
    error_message = "level key must be in [organization, team], got ${jsonencode(var.levels)}"
  }
}

variable "groups" {
  type = map(object({
    force_destroy = optional(bool)
    pw_length     = optional(number)
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

  validation {
    condition     = length([for key, group in var.groups : key]) > 0
    error_message = "level must have at least one group"
  }

  validation {
    condition     = length(flatten([for key, group in var.groups : [for user in group.users : user.name]])) > 0
    error_message = "level must have at least one user"
  }
}

variable "statements" {
  type = list(object({
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
  nullable = false
  default  = []
}

variable "external_assume_role_arns" {
  description = "List of roles to have access to that are external to the team scope"
  type        = list(string)
  nullable    = false
  default     = []
}

variable "store_secrets" {
  description = "Store the environment on aws secret manager"
  type        = bool
  nullable    = false
  default     = true
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}
