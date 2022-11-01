module "mongodb" {
  source = "../../../modules/data-storage/mongodb"

  region                 = var.region
  subnet_id              = var.subnet_id
  vpc_id                 = var.vpc_id
  vpc_security_group_ids = var.vpc_security_group_ids
  common_tags            = var.common_tags
  ami_id                 = var.ami_id
  instance_type          = var.instance_type
  user_data_path         = var.user_data_path
  user_data_args         = var.user_data_args
}

module "ec2_instance" {
  source = "../../components/ec2-instance"

  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.vpc_security_group_ids
  common_tags            = var.common_tags
  cluster_name           = "${var.common_tags["Project"]}-${var.common_tags["Environment"]}-ec2-single"
  ami_id                 = var.ami_id
  instance_type          = var.instance_type
  user_data_path         = var.user_data_path
  user_data_args         = var.user_data_args
}
