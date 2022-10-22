locals {
  service_name = "terraform-state-${var.service}"
  region = var.zones["n.virginia"]
  version = "0.0.1"

  # Common tags to be assigned to all resources
  common_tags = {
    Region = local.region
    Service = local.service_name
    Version = local.version
  }
}

provider "aws" {
  region = local.region
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = local.service_name
 
  # Prevent accidental deletion of this S3 bucket
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}