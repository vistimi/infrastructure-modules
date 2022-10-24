locals {
  bucket_images_name = "${var.cluster_name}-images"
  bucket_db_name     = "${var.cluster_name}-db"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

# S3 for mongodb docker image
module "docker"{
  source = "modules/components/mongodb/docker"
}

# S3 for mongodb state
resource "aws_s3_bucket" "mongodb" {
  bucket = local.bucket_db_name
  tags = merge(var.common_tags, { Name = local.bucket_db_name })
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.mongodb.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 for images
resource "aws_s3_bucket" "images" {
  bucket = local.bucket_images_name
  tags = merge(var.common_tags, { Name = local.bucket_images_name })
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.images.id
  versioning_configuration {
    status = "Enabled"
  }
}

# TODO: mount ec2 with docker

# user_data = templatefile("user-data.sh", {
#     server_port = var.server_port
#     db_address  = data.terraform_remote_state.db.outputs.address
#     db_port     = data.terraform_remote_state.db.outputs.port
#   })
#   # Required when using a launch configuration with an ASG.
#   lifecycle {
#     create_before_destroy = true
#   }

