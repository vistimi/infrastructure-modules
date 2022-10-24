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

# S3 for mongodb docker image
resource "aws_s3_bucket" "docker" {
  bucket = "mongodb-docker-images"
  tags   = { Name = "mongodb-docker-images", Region = "us-east-1" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.docker.id
  versioning_configuration {
    status = "Enabled"
  }
}
