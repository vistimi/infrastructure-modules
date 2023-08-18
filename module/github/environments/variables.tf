variable "name" {
  description = "Environment name"
  type        = string
  nullable    = false
}

variable "repository_names" {
  description = "Repository names"
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.repository_names) > 0
    error_message = "repository names should not be empty"
  }
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
  nullable  = false
  default   = []
  sensitive = true
}
