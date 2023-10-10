# Global
variable "name" {
  description = "The name of the bucket"
  type        = string
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

variable "encryption" {
  description = "Enable server side encryption"
  type = object({
    deletion_window_in_days = optional(number)
  })
  default = null
}

variable "force_destroy" {
  description = "If true, will delete the resources that still contain elements"
  type        = bool
  default     = true
}

variable "versioning" {
  description = "Enable versioning"
  type        = bool
  default     = false
}

variable "bucket_attachement_role_names" {
  description = "List of role names that will have access to this bucket"
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
