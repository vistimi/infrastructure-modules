locals {
  bucket_name_env = "${var.service_name}-env"
}

# ECR
module "ecr" {
  source = "../../../../modules/containers/registry"

  registry_name                     = var.service_name
  repository_read_write_access_arns = var.repository_read_write_access_arns
  common_tags                       = var.common_tags
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last ${var.repository_image_count} images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = var.repository_image_count
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECS
# TODO

# # EC2
# module "ec2-instances" {
#   source = "../../components/ec2-asg"

#   vpc_id            = var.vpc_id
#   subnets_ids       = var.subnets_ids
#   common_tags       = var.common_tags
#   cluster_name      = var.service_name
#   server_port       = var.server_port
#   health_check_path = "/"
#   elb_port          = 80
#   ami_name          = var.ami_name
#   instance_type     = var.instance_type
#   min_size          = var.min_size
#   max_size          = var.max_size
#   public            = true
# }