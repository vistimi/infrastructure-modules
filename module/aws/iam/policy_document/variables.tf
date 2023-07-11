variable "scope" {
  description = "scope to restrain the access to the resource"
  type        = string
  nullable    = false
  default     = "public"
}

variable "statements" {
  type = list(object({
    actions   = list(string)
    resources = list(string)
    effect    = optional(string)
  }))
}

variable "principals_services" {
  description = "the prefix of each service name that is added to principals: [ec2, ecs, ...]"
  type        = list(string)
  nullable    = false
  default     = []
}

variable "account_ids" {
  description = "(Scope `accounts`) extra account ids to give access to the resource"
  type        = list(string)
  nullable    = false
  default     = []
}

variable "vpc_ids" {
  description = "(Scope `microservice`) vpc ids to give access to the resource"
  type        = list(string)
  nullable    = false
  default     = []
}

# TODO: add public, orgs, roles, groups, users
variable "scopes" {
  description = "scopes to restrain the access to the resource"
  type        = list(string)

  default = ["public", "accounts", "microservice"]
}

resource "null_resource" "scopes" {
  lifecycle {
    precondition {
      condition     = contains(var.scopes, var.scope)
      error_message = "policy document scope must be one of ${jsonencode(var.scopes)}"
    }
  }
}
