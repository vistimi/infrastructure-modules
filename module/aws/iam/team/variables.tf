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

variable "repository_name" {
  description = "User names with specific roles"
  type        = string
  nullable    = false
  default     = "repositories"
}

variable "machine_names" {
  description = "List of user names with specific roles"
  type        = list(string)
  nullable    = false
  default     = ["live", "staging"]
}
