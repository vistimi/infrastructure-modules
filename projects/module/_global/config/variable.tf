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

  validation {
    condition     = alltrue([for repository in var.repositories : length(repository.accesses) > 0])
    error_message = "repositories should have at least one element in accesses"
  }
}

# variable "repositories" {
#   type = list(object({
#     owner = string
#     name  = string
#   }))
#   default = []
# }

# variable "repository_variables" {
#   type = list(object({
#     owner = string
#     name  = string
#   }))
#   default = []
# }

# variable "repository_secrets" {
#   type = list(object({
#     owner = string
#     name  = string
#   }))
#   default   = []
#   sensitive = true
# }
