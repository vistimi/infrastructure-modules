variable "name" {
  description = "Organization name"
  type        = string
  nullable    = false
}

variable "store_secrets" {
  description = "Store the environment on aws secret manager"
  type        = bool
  nullable    = false
  default     = true
}

variable "team_names" {
  description = "Team names"
  type = list(object({
    name = string
    admins = list(object({
      name = string
    }))
    devs = list(object({
      name = string
    }))
    machines = list(object({
      name = string
    }))
    resources = list(object({
      name    = string
      mutable = bool
    }))
  }))
  nullable = false
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}