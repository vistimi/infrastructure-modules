variable "aws_region" {
  description = "The region on which the project is running, (e.g `us-east-1`)"
  type        = string
}

variable "backend_name" {
  description = "The name of the backend, e.g. terraform-state-backend-prod"
  type        = string
}