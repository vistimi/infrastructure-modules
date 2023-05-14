# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = var.ami_ssm_name[var.ami_ssm_architecture]
}

module "ec2_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = var.common_name

  ami                         = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami["on-demand"].value)["image_id"]
  instance_type               = var.instance_type
  monitoring                  = true
  vpc_security_group_ids      = var.vpc_security_group_ids
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip_address
  ebs_optimized               = false # optimized ami does not support ebs_optimized

  user_data_base64            = base64encode(var.user_data)
  user_data_replace_on_change = true

  tags = var.common_tags
}