variable "admin_names" {
  description = "List of user names with specific roles"
  type        = list(string)
  nullable    = false
}

variable "dev_names" {
  description = "List of user names with specific roles"
  type        = list(string)
  nullable    = false
}

variable "resource_names" {
  description = "List of User names with specific roles for resources used in other accounts"
  type        = list(string)
  nullable    = false
  default     = ["repositories"]
}

variable "machine_names" {
  description = "List of user names with specific roles for execution"
  type        = list(string)
  nullable    = false
  default     = ["live", "staging"]
}
