variable "name" {
  description = "Environment name"
  type        = string
  nullable    = false
}

variable "repository_name" {
  description = "Repository names"
  type        = string
  nullable    = false
}

variable "variables" {
  description = "List of variables"
  type = list(object({
    key   = string
    value = string
  }))
  nullable = false
  default  = []
}

variable "secrets" {
  description = "List of secrets"
  type = list(object({
    key   = string
    value = string
  }))
  nullable = false
  default  = []
}
