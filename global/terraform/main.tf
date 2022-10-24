terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"

  backend "s3" {
    bucket = "mongodb-docker-images"
    key    = "global/s3/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform-state-backup-locks"
    encrypt        = true
  }
}