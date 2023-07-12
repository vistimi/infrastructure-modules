module "microservice" {
  source = "../../../../module/aws/container/microservice"

  name       = var.name
  tags       = var.tags
  vpc        = var.microservice.vpc
  route53    = var.microservice.route53
  ecs        = var.microservice.ecs
  bucket_env = var.microservice.bucket_env
  iam        = var.microservice.iam
}
