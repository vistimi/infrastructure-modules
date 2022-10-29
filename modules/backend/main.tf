locals {
  storage_name = "${var.backend_name}-storage"
  lock_name = "${var.backend_name}-locks"
}

# S3
resource "aws_s3_bucket" "terraform_storage" {
  bucket = local.storage_name

  tags = { Name = local.storage_name, Region = var.region }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.terraform_storage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB
resource "aws_dynamodb_table" "terraform_locks" {
  name         = local.lock_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name   = local.lock_name
    Region = var.region
  }

  lifecycle {
    prevent_destroy = true
  }
}
