locals {
  data_storage_name    = "${var.common_tags["Project"]}-${var.common_tags["Environment"]}"
  bucket_name_pictures = var.user_data_args["bucket_name_pictures"]
  bucket_name_mongodb  = var.user_data_args["bucket_name_mongodb"]
}

# S3 for mongodb
module "mongodb" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = local.bucket_name_mongodb
  acl    = "private"

  versioning = {
    enabled = true
  }

  attach_policy = true
  policy = {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllS3",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": "arn:aws:s3:::${local.bucket_name_mongodb}/*",
            "Condition": {
                "StringEquals": {
                    "aws:SourceVpce": "${var.vpc_id}"
                }
            }
        }
    ]
}

  tags   = merge(var.common_tags, { Name = local.bucket_name_mongodb })

}

# S3 for pictures
module "pictures" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = local.bucket_name_pictures
  acl    = "private"

  versioning = {
    enabled = true
  }

  attach_policy = true
  policy = {}

  tags   = merge(var.common_tags, { Name = local.bucket_name_pictures })
}

# EC2
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

