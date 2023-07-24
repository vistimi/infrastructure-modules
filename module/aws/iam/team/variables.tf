variable "name" {
  description = "Team name"
  type        = string
  nullable    = false
}

variable "groups" {
  type = object({
    groups = list(object({
      name = string
      group = object({
        force_destroy = optional(bool)
        admin         = bool
        poweruser     = bool
        readonly      = bool
        pw_length     = optional(number)
        users = list(object({
          name = string
          statements = optional(list(object({
            sid       = optional(string)
            actions   = list(string)
            effect    = optional(string)
            resources = list(string)
          })))
        }))
        statements = optional(list(object({
          sid       = optional(string)
          actions   = list(string)
          effect    = optional(string)
          resources = list(string)
        })))
      })
    }))
    statements = optional(list(object({
      sid       = optional(string)
      actions   = list(string)
      effect    = optional(string)
      resources = list(string)
    })), [])
  })

  validation {
    condition     = length(concat(var.resource.users, var.machine.users, var.dev.users, var.admin.users)) > 0
    error_message = "team must have at least one user"
  }
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
