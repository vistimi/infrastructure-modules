locals {
  all_cidrs_ipv4 = "0.0.0.0/0"
  # all_cidrs_ipv6 = "::/0"

  data_storage_name    = var.data_storage_name
  bucket_name_pictures = var.user_data_args["bucket_name_pictures"]
  bucket_name_mongodb  = var.user_data_args["bucket_name_mongodb"]
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Tier = "Private"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Tier = "Public"
  }
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

  force_destroy = var.force_destroy

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

  force_destroy = var.force_destroy

  attach_policy = true
  policy        = data.aws_iam_policy_document.bucket_policy_pictures.json

  tags = merge(var.common_tags, { Name = local.bucket_name_pictures })
}

# EC2
# module "key_pair" {
#   count = var.bastion ? 1 : 0

#   source = "terraform-aws-modules/key-pair/aws"

#   key_name              = local.data_storage_name
#   private_key_algorithm = "ED25519"
#   create_private_key    = true
# }

# resource "local_file" "tf-key-file" {
#   count = var.bastion ? 1 : 0

#   # content  = module.key_pair[0].private_key_openssh
#   content  = module.key_pair[0].private_key_pem
#   filename = "${module.key_pair[0].key_pair_name}.pem"
# }

resource "tls_private_key" "this" {
  count = var.bastion ? 1 : 0
  
  algorithm     = "RSA"
  rsa_bits      = 4096
}

resource "aws_key_pair" "key_pair" {
  count = var.bastion ? 1 : 0

  key_name   = local.data_storage_name
  public_key = tls_private_key.this[0].public_key_openssh

  provisioner "local-exec" {
    command = <<-EOT
      echo "${tls_private_key.this[0].private_key_pem}" > ${local.data_storage_name}.pem
    EOT
  }
}

module "ec2_instance_sg_ssh" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${local.data_storage_name}-sg-ssh"
  description = "Security group for SSH"
  vpc_id      = var.vpc_id

  ingress_cidr_blocks = [local.all_cidrs_ipv4]
  ingress_rules       = ["ssh-tcp"]
}

module "ec2_instance_sg_mongodb" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${local.data_storage_name}-sg-ssh"
  description = "Security group for Mongodb"
  vpc_id      = var.vpc_id

  ingress_cidr_blocks = [local.all_cidrs_ipv4]
  ingress_rules       = ["mongodb-27017-tcp"]
}

module "ec2_instance_mongodb" {
  source = "../../components/ec2-instance"

  subnet_id = data.aws_subnets.private.ids[0]
  vpc_security_group_ids = concat(
    var.vpc_security_group_ids,
    concat(
      [module.ec2_instance_sg_mongodb.security_group_id],
      var.bastion ? [module.ec2_instance_sg_ssh.security_group_id] : []
    )
  )
  common_tags                 = var.common_tags
  cluster_name                = "${local.data_storage_name}-mongodb"
  ami_id                      = var.ami_id
  key_name                    = local.data_storage_name
  instance_type               = var.instance_type
  user_data_path              = var.user_data_path
  user_data_args              = var.user_data_args
  aws_access_key              = var.aws_access_key
  aws_secret_key              = var.aws_secret_key
  associate_public_ip_address = false
}

module "ec2_instance_bastion" {
  count = var.bastion ? 1 : 0

  source = "../../components/ec2-instance"

  subnet_id                   = data.aws_subnets.public.ids[0]
  vpc_security_group_ids      = concat(var.vpc_security_group_ids, [module.ec2_instance_sg_ssh.security_group_id])
  common_tags                 = var.common_tags
  cluster_name                = "${local.data_storage_name}-bastion"
  ami_id                      = var.ami_id
  key_name                    = local.data_storage_name
  instance_type               = var.instance_type
  aws_access_key              = var.aws_access_key
  aws_secret_key              = var.aws_secret_key
  associate_public_ip_address = true
}

