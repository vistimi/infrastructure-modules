variable "name_prefix" {
  description = "The name prefix that comes after the microservice name"
  type        = string
  default     = ""
}

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

variable "backend" {
  type = object({
    bucket_name         = optional(string, "tf-state")
    dynamodb_table_name = optional(string, "tf-locks")
  })
  default = {}
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
