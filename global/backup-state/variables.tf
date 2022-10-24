variable "region" {
  description = "The region on which the project is running, (e.g `us-east-1`)"
  type        = string
}

variable "backup_name" {
  description = "The name of backup used to store and lock the states"
  type        = string
}