variable "names" {
  description = "Environment name"
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.names) > 0
    error_message = "names should not be empty"
  }
}

variable "secrets" {
  description = "List of secrets"
  type = list(object({
    key   = string
    value = string
  }))
  nullable  = false
  default   = []
#   sensitive = true
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}
