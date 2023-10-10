variable "name" {
  description = "Environment name"
  type        = string
  nullable    = false
}

variable "secrets" {
  description = "List of secrets"
  type = list(object({
    key   = string
    value = string
  }))
  nullable = false
  default  = []
  #   sensitive = true
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}
