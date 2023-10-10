variable "organization" {
  type = object({
    variables = optional(list(object({
      key   = string
      value = string
    })), [])
    secrets = optional(list(object({
      key   = string
      value = string
    })), [])
  })
  default = {}
}

variable "repositories" {
  type = list(object({
    accesses = optional(list(object({
      owner = string
      name  = string
    })), [])
    variables = optional(list(object({
      key   = string
      value = string
    })), [])
    secrets = optional(list(object({
      key   = string
      value = string
    })), [])
  }))
  default = []
}

variable "environments" {
  type = list(object({
    name = string
    accesses = optional(list(object({
      owner = string
      name  = string
    })), [])
    variables = optional(list(object({
      key   = string
      value = string
    })), [])
    secrets = optional(list(object({
      key   = string
      value = string
    })), [])
  }))
  default = []
}
