variable "name" {
  type     = string
  nullable = false
}

variable "levels" {
  description = "Levels of hierarchy before the group, order matters!"
  type = list(object({
    key   = string
    value = string
  }))
  default = []
}

variable "force_destroy" {
  type     = bool
  nullable = false
  default  = false
}

variable "pw_length" {
  type     = number
  nullable = false
  default  = 20
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
