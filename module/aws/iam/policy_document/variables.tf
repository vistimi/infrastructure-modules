variable "vpc_tag_name" {
  description = "tag for vpc id"
  type        = string
  default     = "VpcId"
}

variable "tags" {
  description = "Custom tags"
  type        = map(string)
  default     = {}

  validation {
    condition     = length(try(var.tags["VpcId"], "")) > 0
    error_message = "missing the tag `VpcId` in tags: ${jsonencode(var.tags)}"
  }
}

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
  description = "(Scope `microservices`) vpc ids to give access to the resource"
  type        = list(string)
  nullable    = false
  default     = []
}

# TODO: add public, orgs, roles, groups, users
variable "scopes" {
  description = "scopes to restrain the access to the resource"
  type        = list(string)

  default = ["public", "accounts", "microservices"]
}

resource "null_resource" "scopes" {
  lifecycle {
    precondition {
      condition     = contains(var.scopes, var.scope)
      error_message = "policy document scope must be one of ${jsonencode(var.scopes)}"
    }
  }
}
