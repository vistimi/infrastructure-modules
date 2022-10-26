terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"

  backend "s3" {
    bucket         = "terraform-state-backend-storage"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-backend-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  bucket_name = "global-mount-helper"
}

# S3 for helping to mount instances to buckets
resource "aws_s3_bucket" "mount" {
  bucket = local.bucket_name
  tags   = { Name = local.bucket_name, Region = "us-east-1" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.mount.id
  versioning_configuration {
    status = "Enabled"
  }
}
