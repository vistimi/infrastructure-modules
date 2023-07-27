variable "levels" {
  description = "Levels of hierarchy before the group, order matters!"
  type = list(object({
    key   = string
    value = string
  }))
  default = []
}

variable "name" {
  description = "Group name, e.g. admin, dev..."
  type        = string
  nullable    = false
}

# variable "attach_iam_self_management_policy" {
#   description = "Create self management policy of all resources with mfa"
#   type        = bool
#   nullable    = false
#   default     = false
# }

variable "force_destroy" {
  type     = bool
  nullable = false
  default  = false
}

variable "create_admin_role" {
  type     = bool
  nullable = false
  default  = false
}

variable "create_poweruser_role" {
  type     = bool
  nullable = false
  default  = false
}

variable "create_readonly_role" {
  type     = bool
  nullable = false
  default  = false
}

variable "attach_role_name" {
  type    = string
  default = null

  validation {
    condition     = contains(["admin", "poweruser", "readonly", null], var.attach_role_name)
    error_message = "attach role name must be in [admin, poweruser, readonly] or null"
  }
}

resource "null_resource" "role_attachement" {
  lifecycle {
    precondition {
      condition     = var.attach_role_name == "admin" ? var.create_admin_role : true
      error_message = "to attach the admin role, it must be created"
    }
    precondition {
      condition     = var.attach_role_name == "poweruser" ? var.create_poweruser_role : true
      error_message = "to attach the poweruser role, it must be created"
    }
    precondition {
      condition     = var.attach_role_name == "readonly" ? var.create_readonly_role : true
      error_message = "to attach the readonly role, it must be created"
    }
  }
}

variable "pw_length" {
  type     = number
  nullable = false
  default  = 20
}

variable "users" {
  type = list(object({
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
  default = []

  validation {
    condition     = length([for user in var.users : user.name]) > 0
    error_message = "group must have at least one user"
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
  description = "List of roles external to the group"
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
