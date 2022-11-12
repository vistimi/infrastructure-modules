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
  # user_data_base64            = base64encode(data.template_file.user_data.rendered)
  user_data_replace_on_change = true

  tags = var.common_tags
}

# # AMI
# module "ami" {
#   source   = "../ami"
#   ami_name = var.ami_name
# }

# # Security Group
# resource "aws_security_group" "instance" {
#   name        = var.instance_security_group_name
#   description = "Default security group to allow inbound/outbound for the instance"

#   tags = merge(var.common_tags, { Name = "${var.cluster_name}-ec2-sg" })

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_security_group_rule" "allow_all_inbound_ipv4" {
#   type              = "ingress"
#   security_group_id = aws_security_group.instance.id

#   from_port   = var.server_port
#   to_port     = var.server_port
#   protocol    = local.tcp_protocol
#   cidr_blocks = [local.all_cidrs_ipv4] // TODO: cidr from backend sg
# }

# resource "aws_security_group_rule" "allow_all_outbound_ipv4" {
#   type              = "egress"
#   security_group_id = aws_security_group.instance.id

#   from_port   = local.any_port
#   to_port     = local.any_port
#   protocol    = local.any_protocol
#   cidr_blocks = [local.all_cidrs_ipv4]
# }

# # EC2
# resource "aws_instance" "instance" {
#   ami                         = data.aws_ami.ubuntu.id
#   instance_type               = var.instance_type
#   security_groups             = [aws_security_group.instance.id]
#   key_name                    = var.key_name
#   monitoring                  = true
#   associate_public_ip_address = var.public

#   subnet_id = var.subnet_id

#   user_data = templatefile(var.user_data_path, var.user_data_args)

#   tags = merge(var.common_tags, { Name = "${var.cluster_name}-ec2" })

#   lifecycle {
#     create_before_destroy = true
#   }
# }
