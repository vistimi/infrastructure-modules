variable "zones" {
  type = map
  description = "timezones used"
  default = {
    "n.virginia" = "us-east-1"
  }
}

variable "roles" {
  type = list
  description = "roles used"
  default = ["administrator"]
}

variable "projects" {
  type = list
  description = "available projects"
  default = ["scraper"]
}