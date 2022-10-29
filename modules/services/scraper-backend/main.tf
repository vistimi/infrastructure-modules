locals {
  asg_name = "{var.service_name}-${var.environment_name}-asg"
}

# ECR
module "ecr" {
  source = "../../../../modules/containers/registry"

  project_name              = var.project_name
  environment_name          = var.environment_name
  common_tags               = local.common_tags
}

# EC2
module "ec2-asg" {
  source = "../../components/ec2-asg"

  vpc_id            = var.vpc_id
  subnets_ids       = var.subnets_ids
  common_tags       = var.common_tags
  cluster_name      = "${var.service_name}-${var.environment_name}-ec2-cluster"
  server_port       = var.server_port
  health_check_path = var.health_check_path
  elb_port          = var.elb_port
  ami_name          = var.ami_name
  instance_type     = var.instance_type
  min_size          = var.min_size
  max_size          = var.max_size
  public            = true
}

# MongoDB
module "mongodb" {
  source = "../../data-storage/mongodb"

  vpc_id            = var.vpc_id
  subnet_id         = var.subnets_ids[0]
  common_tags       = var.common_tags
  server_port       = var.server_port
  health_check_path = var.health_check_path
  ami_name          = var.ami_name
  instance_type     = var.instance_type
  user_data_path    = var.user_data_path
  user_data_args    = var.user_data_args
}