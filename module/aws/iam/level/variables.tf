variable "name" {
  description = "Level name"
  type        = string
  nullable    = false
}

# variable "level" {
#   description = "Level type"
#   type        = string
#   nullable    = false

#   validation {
#     condition     = contains(["organization", "team"])
#     error_message = "level must be in [organization, team]"
#   }
# }

variable "store_secrets" {
  description = "Store the environment on aws secret manager"
  type        = bool
  nullable    = false
  default     = true
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}
