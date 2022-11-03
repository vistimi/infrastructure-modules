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

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.mount.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
