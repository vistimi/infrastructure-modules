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

variable "account_ids" {
  description = "(Scope `accounts`) extra account ids to give access to the resource"
  type        = list(string)
  nullable    = false
  default     = []
}

variable "vpc_ids" {
  description = "(Scope `vpc`) vpc ids to give access to the resource"
  type        = list(string)
  nullable    = false
  default     = []
}

variable "group_names" {
  description = "(Scope `groups`) name prefixes to give access to the resource"
  type        = list(string)
  nullable    = false
  default     = []
}

variable "user_names" {
  description = "(Scope `users`) name prefixes to give access to the resource"
  type        = list(string)
  nullable    = false
  default     = []
}

variable "scopes" {
  description = "scopes to restrain the access to the resource"
  type        = list(string)

  default = ["public", "accounts", "vpcs", "groups", "users"]
}

variable "requires_mfa" {
  description = "Whether users requires MFA"
  type        = bool
  default     = false
}

variable "mfa_age" {
  description = "Max age of valid MFA (in seconds) for roles which require MFA"
  type        = number
  default     = 86400
}

variable "tags" {
  description = "Custom tags"
  type        = map(string)
  default     = {}
}

locals {
  account_ids = distinct(compact(concat(var.account_ids, [local.account_id])))
}

resource "null_resource" "scopes" {
  lifecycle {
    precondition {
      condition     = contains(var.scopes, var.scope)
      error_message = "policy document scope must be one of ${jsonencode(var.scopes)}"
    }
  }
}

resource "null_resource" "accounts" {
  for_each = var.scope == "accounts" ? { "${var.scope}" = {} } : {}
  lifecycle {
    precondition {
      condition     = length(local.account_ids) > 0
      error_message = "scope accounts must have at least one element in account_ids: ${jsonencode(local.account_ids)}"
    }
  }
}

resource "null_resource" "vpcs" {
  for_each = var.scope == "vpcs" ? { "${var.scope}" = {} } : {}
  lifecycle {
    precondition {
      condition     = length(var.vpc_ids) > 0
      error_message = "scope vpcs must have at least one element in vpc_ids: ${jsonencode(var.vpc_ids)}"
    }
  }
}

resource "null_resource" "groups" {
  for_each = var.scope == "groups" ? { "${var.scope}" = {} } : {}
  lifecycle {
    precondition {
      condition     = length(var.group_names) > 0
      error_message = "scope groups must have at least one element in group_names: ${jsonencode(var.group_names)}"
    }
  }
}

resource "null_resource" "users" {
  for_each = var.scope == "users" ? { "${var.scope}" = {} } : {}
  lifecycle {
    precondition {
      condition     = length(var.user_names) > 0
      error_message = "scope users must have at least one element in user_names: ${jsonencode(var.user_names)}"
    }
  }
}
