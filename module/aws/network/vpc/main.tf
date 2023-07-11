locals {
  # # increment from `0.0.0.0/16` to `0.0.16.0/16`
  subnets = {
    for i, tier in var.tier_tags :
    "${tier}" => [for az_idx in range(0, length(data.aws_availability_zones.available.names)) : cidrsubnet(var.cidr_ipv4, 4, i * length(data.aws_availability_zones.available.names) + az_idx)]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.name
  cidr = var.cidr_ipv4

  # only one NAT
  enable_nat_gateway     = var.enable_nat
  single_nat_gateway     = var.enable_nat
  one_nat_gateway_per_az = false

  azs             = data.aws_availability_zones.available.names
  public_subnets  = local.subnets["public"]
  private_subnets = local.subnets["private"]

  private_subnet_tags = { Tier = "private" }
  public_subnet_tags  = { Tier = "public" }

  tags = merge(var.tags, { Zones = jsonencode(data.aws_availability_zones.available.names) })
}
