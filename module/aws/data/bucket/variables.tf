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

variable "vpc_id" {
  description = "The IDs of the VPC which contains the subnets"
  type        = string
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
    scope       = string
    account_ids = optional(string)
    vpc_ids     = optional(string)
  })
}
