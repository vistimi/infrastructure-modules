locals {
  service                = "${var.service_name}-${var.environment_name}"
  cluster_name           = "${service}-ec2-cluster"
}

module "ec2-asg" {
  source = "modules/components/ec2-asg"

  common_tags = var.common_tags
  vpc_id            = var.vpc_id
  subnets_ids       = var.subnets_ids
  cluster_name      = local.cluster_name
  server_port       = var.server_port
  health_check_path = var.health_check_path
  elb_port          = var.elb_port
  ami_name          = var.ami_name
  instance_type     = var.instance_type
  min_size          = var.min_size
  max_size          = var.max_size
}