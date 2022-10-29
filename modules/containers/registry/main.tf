module "ecr" {
  source = "terraform-aws-modules/ecr/aws"
  version = "~> 1.4.0"

  repository_name = "${var.project_name}-${var.environment_name}-ecr"

  repository_read_write_access_arns = ["arn:aws:iam::012345678901:role/terraform"]
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 10 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 10
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = var.common_tags
}