locals {
  data_storage_name = var.data_storage_name
  bucket_name_pictures = var.user_data_args["bucket_name_pictures"]
  bucket_name_mongodb  = var.user_data_args["bucket_name_mongodb"]
  key_name = var.bastion ? module.key_pair[0].key_pair_name : null
}

# S3 for mongodb
data "aws_iam_policy_document" "bucket_policy_mongodb" {
  statement {
    principals {
      type = "Service"
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
      type = "Service"
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
module "key_pair" {
  count = var.bastion ? 1 : 0

  source = "terraform-aws-modules/key-pair/aws"

  key_name           = local.data_storage_name
  private_key_algorithm = "ED25519"
  create_private_key = true
}

resource "local_file" "tf-key-file" {
  count = var.bastion ? 1 : 0

  content  = module.key_pair[0].private_key_pem
  filename = "${local.data_storage_name}.pem"
}

module "ec2_instance_mongodb" {
  source = "../../components/ec2-instance"

  subnet_id              = var.private_subnets[0]
  vpc_security_group_ids = var.vpc_security_group_ids
  common_tags            = var.common_tags
  cluster_name           = "${local.data_storage_name}-mongodb"
  ami_id                 = var.ami_id
  key_name               = local.key_name
  instance_type          = var.instance_type
  user_data_path         = var.user_data_path
  user_data_args         = var.user_data_args
}

module "ec2_instance_bastion" {
  count = var.bastion ? 1 : 0

  source = "../../components/ec2-instance"

  subnet_id              = var.public_subnets[0]
  vpc_security_group_ids = var.vpc_security_group_ids
  common_tags            = var.common_tags
  cluster_name           = "${local.data_storage_name}-bastion"
  ami_id                 = var.ami_id
  key_name               = local.key_name
  instance_type          = var.instance_type
  user_data_path         = var.user_data_path
  user_data_args         = var.user_data_args
}

