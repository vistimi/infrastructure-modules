data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_subnets" "tier" {
  filter {
    name   = "vpc-id"
    values = [var.vpc.id]
  }
  tags = {
    Tier = var.vpc.tier
  }
}
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = var.ami_ssm_name[var.instance.ec2.ami_ssm_architecture]
  # name = "${var.ami_ssm_name[var.instance.ec2.ami_ssm_architecture]}/image_id"
}

locals {
  account_id        = data.aws_caller_identity.current.account_id
  account_arn       = data.aws_caller_identity.current.arn
  dns_suffix        = data.aws_partition.current.dns_suffix // amazonaws.com
  partition         = data.aws_partition.current.partition  // aws
  region            = data.aws_region.current.name
  subnets           = data.aws_subnets.tier.ids
  image_id          = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
  ecs_agent_version = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["ecs_agent_version"]
  # image_id = data.aws_ssm_parameter.ecs_optimized_ami.value
}
