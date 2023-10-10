variable "name" {
  description = "The name of the repository"
  type        = string
}

variable "tags" {
  description = "Custom tags"
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "If true, will delete the resources that still contain elements"
  type        = bool
  default     = true
}

variable "image_keep_count" {
  description = "The amount of images to keep in the repository"
  type        = number
  default     = 1
}

variable "privacy" {
  description = "The privacy of the repository"
  type        = string

  validation {
    condition     = contains(["private", "public", "intra"], var.privacy)
    error_message = "repository privacy must be one of [public, private, intra]"
  }
}

variable "repository_attachement_role_names" {
  description = "List of role names that will have access to this repository"
  type        = list(string)
  default     = []
}

variable "iam" {
  type = object({
    scope        = string
    requires_mfa = optional(bool)
    mfa_age      = optional(number)
    account_ids  = optional(list(string))
    vpc_ids      = optional(list(string))
  })
}
