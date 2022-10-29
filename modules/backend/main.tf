locals {
  storage_name = "${var.backend_name}-storage"
  lock_name    = "${var.backend_name}-locks"
}

# S3
module "terraform_storage" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = local.storage_name
  acl    = "private"

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    sse_algorithm = "AES256"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = { Name = local.storage_name, Region = var.region }
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
