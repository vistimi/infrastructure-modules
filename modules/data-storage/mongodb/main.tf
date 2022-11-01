locals {
  data_storage_name    = "${var.common_tags["Project"]}-${var.common_tags["Environment"]}"
  bucket_name_pictures = var.user_data_args["bucket_name_pictures"]
  bucket_name_mongodb  = var.user_data_args["bucket_name_mongodb"]
}

# S3 for mongodb
data "aws_iam_policy_document" "bucket_policy_mongodb" {
  statement {
    principals {
      type        = "Service"
      identifiers = [
        "ecs.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
        ]
    }

    actions = [
      "s3:*",
    ]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:SourceVpce"
      values   = ["${var.vpc_id}"]
    }

    resources = [
      "arn:aws:s3:::${local.bucket_name_mongodb}/*",
    ]
  }
}

module "s3_bucket_mongodb" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = local.bucket_name_mongodb
  acl    = "private"

  versioning = {
    enabled = true
  }

  attach_policy = true
  policy        = data.aws_iam_policy_document.bucket_policy_mongodb.json

  tags = merge(var.common_tags, { Name = local.bucket_name_mongodb })
}

# S3 for pictures
data "aws_iam_policy_document" "bucket_policy_pictures" {
  statement {
    principals {
      type        = "Service"
      identifiers = [
        "ecs.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
        ]
    }

    actions = [
      "s3:*",
    ]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:SourceVpce"
      values   = ["${var.vpc_id}"]
    }

    resources = [
      "arn:aws:s3:::${local.bucket_name_pictures}/*",
    ]
  }
}

module "s3_bucket_pictures" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = local.bucket_name_pictures
  acl    = "private"

  versioning = {
    enabled = true
  }

  attach_policy = true
  policy        = data.aws_iam_policy_document.bucket_policy_pictures.json

  tags = merge(var.common_tags, { Name = local.bucket_name_pictures })
}

# EC2
module "ec2_instance" {
  source = "../../components/ec2-instance"

  # vpc_id            = var.vpc_id
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.vpc_security_group_ids
  common_tags            = var.common_tags
  cluster_name           = "${local.data_storage_name}-mongodb-ec2"
  ami_id                 = var.ami_id
  instance_type          = var.instance_type
  user_data_path         = var.user_data_path
  user_data_args         = var.user_data_args
}

