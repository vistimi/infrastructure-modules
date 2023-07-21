variable "name" {
  description = "Team name"
  type        = string
  nullable    = false
}

variable "aws" {
  type = object({
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
    store_secrets = bool
    tags          = map(string)
  })

  validation {
    condition     = length(concat(var.aws.resources, var.aws.machines, var.aws.devs, var.aws.admins)) > 0
    error_message = "team must have at least one user"
  }
}

variable "github" {
  type = object({
    repository_names  = list(string)
    store_environment = bool
  })

  validation {
    condition     = var.github.store_environment ? length(var.github.repository_names) > 0 : true
    error_message = "if store github is true, github repository names should not be empty"
  }
}
