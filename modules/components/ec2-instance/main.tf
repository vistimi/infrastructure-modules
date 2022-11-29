# locals {
#   any_port       = 0
#   any_protocol   = "-1"
#   http_protocol  = "HTTP"
#   tcp_protocol   = "tcp"
#   all_cidrs_ipv4 = "0.0.0.0/0"
#   all_cidrs_ipv6 = "::/0"
# }

locals{
  user_data_args=merge(var.user_data_args, {aws_access_key: var.aws_access_key, aws_secret_key: var.aws_secret_key})
}

# data "template_file" "user_data" {
#   template = "${file("${path.module}/${var.user_data_path}")}"
#   vars = local.user_data_args
# }

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = var.cluster_name

  ami                    = var.ami_id
  instance_type          = var.instance_type
  monitoring             = true
  vpc_security_group_ids = var.vpc_security_group_ids
  subnet_id              = var.subnet_id
  key_name               = var.key_name
  associate_public_ip_address = var.associate_public_ip_address

  user_data_base64            = var.user_data_path != "" ? base64encode(templatefile("${path.module}/${var.user_data_path}", local.user_data_args)) : null
  user_data_replace_on_change = true

  tags = var.common_tags
}