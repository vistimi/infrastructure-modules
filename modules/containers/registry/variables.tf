variable "registry_name" {
  description = "The name of the registry"
  type        = string
}

variable "repository_read_write_access_arns" {
  description = "the ARNs of the roles"
  type = list(string)
}

variable "policy" {
  description = "The policy to give to the registry"
  type        = string
}

variable "common_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}
