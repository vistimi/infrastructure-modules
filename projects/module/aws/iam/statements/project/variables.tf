variable "root_path" {
  type     = string
  nullable = false
}

variable "project_names" {
  type     = list(string)
  default  = []
  nullable = false

  validation {
    condition     = alltrue([for project_name in var.project_names : contains(["scraper"], project_name)])
    error_message = "project names must be in [scraper]"
  }
}

variable "user_name" {
  type     = string
  nullable = false
  default  = "*"
}

variable "branch_name" {
  type     = string
  nullable = false
  default  = "*"
}
