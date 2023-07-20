variable "admins" {
  description = "List of user names with specific roles"
  type = list(object({
    name = string
  }))
  nullable = false
  default  = []
}

variable "devs" {
  description = "List of user names with specific roles"
  type = list(object({
    name = string
  }))
  nullable = false
  default  = []
}

variable "machines" {
  description = "List of user names with specific roles for execution"
  type = list(object({
    name = string
  }))
  nullable = false
  default  = [{ name = "live" }, { name = "staging" }]
}

variable "resources" {
  description = "List of User names with specific roles for resources used in other accounts"
  type = list(object({
    name    = string
    mutable = bool
  }))
  nullable = false
  default  = [{ name = "repositories", mutable = false }, { name = "dns", mutable = true }]
}
