variable "levels" {
  description = "Levels of hierarchy before the group, order matters!"
  type = list(object({
    key   = string
    value = string
  }))
  default = []
}

variable "group_key" {
  description = "Group name, e.g. admin, dev..."
  type        = string
  nullable    = false
}

variable "force_destroy" {
  type     = bool
  nullable = false
  default  = false
}

variable "admin" {
  type     = bool
  nullable = false
}

variable "poweruser" {
  type     = bool
  nullable = false
}

variable "readonly" {
  type     = bool
  nullable = false
}

variable "pw_length" {
  type     = number
  nullable = false
  default  = 20
}

variable "users" {
  type = list(object({
    name = string
  }))
  default = []

  validation {
    condition     = length([for user in var.users : user.name]) > 0
    error_message = "group must have at least one user"
  }
}

# statements = optional(list(object({
#   sid       = optional(string)
#   actions   = list(string)
#   effect    = optional(string)
#   resources = list(string)
# })), [])

variable "statements" {
  type = list(object({
    sid       = optional(string)
    actions   = list(string)
    effect    = optional(string)
    resources = list(string)
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
