variable "team_names" {
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
