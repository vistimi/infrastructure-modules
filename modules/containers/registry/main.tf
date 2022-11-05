module "ecr" {
  source = "terraform-aws-modules/ecr/aws"
  version = "~> 1.4.0"

  repository_name = var.registry_name

  repository_read_write_access_arns = var.repository_read_write_access_arns
  repository_lifecycle_policy = var.policy

  tags = var.common_tags
}