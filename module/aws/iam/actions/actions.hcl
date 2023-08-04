locals {
  # IAM
  iam_vars                  = read_terragrunt_config("${get_terragrunt_dir()}/resources/iam.hcl")
  iam_read                  = local.iam_vars.locals.read
  iam_list                  = local.iam_vars.locals.list
  iam_write                 = local.iam_vars.locals.write
  iam_permission_management = local.iam_vars.locals.permission_management
  iam_tagging               = local.iam_vars.locals.tagging

  # ECR Private
  ecr_vars                  = read_terragrunt_config("${get_terragrunt_dir()}/resources/ecr.hcl")
  ecr_read                  = local.ecr_vars.locals.read
  ecr_list                  = local.ecr_vars.locals.list
  ecr_write                 = local.ecr_vars.locals.write
  ecr_permission_management = local.ecr_vars.locals.permission_management
  ecr_tagging               = local.ecr_vars.locals.tagging

  # ECR Public
  ecr_public_vars                  = read_terragrunt_config("${get_terragrunt_dir()}/resources/ecr-public.hcl")
  ecr_public_read                  = local.ecr_public_vars.locals.read
  ecr_public_list                  = local.ecr_public_vars.locals.list
  ecr_public_write                 = local.ecr_public_vars.locals.write
  ecr_public_permission_management = local.ecr_public_vars.locals.permission_management
  ecr_public_tagging               = local.ecr_public_vars.locals.tagging

  # S3
  s3_vars                  = read_terragrunt_config("${get_terragrunt_dir()}/resources/s3.hcl")
  s3_read                  = local.s3_vars.locals.read
  s3_list                  = local.s3_vars.locals.list
  s3_write                 = local.s3_vars.locals.write
  s3_permission_management = local.s3_vars.locals.permission_management
  s3_tagging               = local.s3_vars.locals.tagging

  # Route53
  route53_vars                  = read_terragrunt_config("${get_terragrunt_dir()}/resources/route53.hcl")
  route53_read                  = local.route53_vars.locals.read
  route53_list                  = local.route53_vars.locals.list
  route53_write                 = local.route53_vars.locals.write
  route53_permission_management = local.route53_vars.locals.permission_management
  route53_tagging               = local.route53_vars.locals.tagging

  # ACM
  acm_vars                  = read_terragrunt_config("${get_terragrunt_dir()}/resources/acm.hcl")
  acm_read                  = local.acm_vars.locals.read
  acm_list                  = local.acm_vars.locals.list
  acm_write                 = local.acm_vars.locals.write
  acm_permission_management = local.acm_vars.locals.permission_management
  acm_tagging               = local.acm_vars.locals.tagging

  # Dynamodb
  dynamodb_vars                  = read_terragrunt_config("${get_terragrunt_dir()}/resources/dynamodb.hcl")
  dynamodb_read                  = local.dynamodb_vars.locals.read
  dynamodb_list                  = local.dynamodb_vars.locals.list
  dynamodb_write                 = local.dynamodb_vars.locals.write
  dynamodb_permission_management = local.dynamodb_vars.locals.permission_management
  dynamodb_tagging               = local.dynamodb_vars.locals.tagging
}
