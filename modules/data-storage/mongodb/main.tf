locals {
  data_storage_name    = "${var.common_tags["Project"]}-${var.common_tags["Environment"]}"
  bucket_name_pictures = var.user_data_args["bucket_name_pictures"]
  bucket_name_mongodb  = var.user_data_args["bucket_name_mongodb"]
}

# S3 for mongodb docker image
module "docker" {
  source = "global/docker"
}

# S3 for mongodb state
resource "aws_s3_bucket" "mongodb" {
  bucket = local.bucket_name_mongodb

  tags   = merge(var.common_tags, { Name = local.bucket_name_mongodb })
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.mongodb.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 for pictures
resource "aws_s3_bucket" "pictures" {
  bucket = local.bucket_name_pictures
  
  tags   = merge(var.common_tags, { Name = local.bucket_name_pictures })
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.pictures.id
  versioning_configuration {
    status = "Enabled"
  }
}

module "ec2_single" {
  source = "../../components/ec2-single"

  vpc_id            = var.vpc_id
  subnet_id         = var.subnet_id
  common_tags       = var.common_tags
  cluster_name      = "${local.data_storage_name}-ec2"
  server_port       = var.server_port
  health_check_path = var.health_check_path
  ami_name          = var.ami_name
  instance_type     = var.instance_type
  public            = false
  user_data_path    = var.user_data_path
  user_data_args    = var.user_data_args
}

