variable "name" {
  description = "Team name"
  type        = string
  nullable    = false
}

variable "admins" {
  description = "List of user names with specific roles"
  type = list(object({
    name = string
  }))
  nullable = false
  default  = []
}

variable "devs" {
  description = "List of user names with specific roles"
  type = list(object({
    name = string
  }))
  nullable = false
  default  = []
}

variable "machines" {
  description = "List of user names with specific roles for execution"
  type = list(object({
    name = string
  }))
  nullable = false
  default  = []
}

variable "resources" {
  description = "List of User names with specific roles for resources used in other accounts. Mutable is for access to route53 for example, immutable is for ECR access for example. Reource users will need to be closed manually if resources still exists."
  type = list(object({
    name    = string
    mutable = bool
  }))
  nullable = false
  default  = []
}

resource "null_resource" "users" {
  lifecycle {
    precondition {
      condition     = length(concat(var.resources, var.machines, var.devs, var.admins)) > 0
      error_message = "team must have at least one user"
    }
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
