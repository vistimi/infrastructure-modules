locals {
  vpc_availability_zones = 3
  # increment from `0.0.0.0/20` to `0.0.16.0/20`
  cidrs_ipv4         = try(cidrsubnets(var.vpc_cidr_ipv4, 4, 4, 4, 4, 4, 4), [])
  public_cidrs_ipv4  = try(slice(local.cidrs_ipv4, 0, local.vpc_availability_zones), [])
  private_cidrs_ipv4 = try(slice(local.cidrs_ipv4, local.vpc_availability_zones, length(local.cidrs_ipv4)), [])
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.vpc_name
  cidr = var.vpc_cidr_ipv4

  # only one NAT
  enable_nat_gateway     = var.enable_nat
  single_nat_gateway     = var.enable_nat
  one_nat_gateway_per_az = false

  azs             = slice(data.aws_availability_zones.available.names, 0, min(local.vpc_availability_zones, length(data.aws_availability_zones.available.names)))
  public_subnets  = local.public_cidrs_ipv4
  private_subnets = local.private_cidrs_ipv4

  private_subnet_tags = { Tier = "Private" }
  public_subnet_tags  = { Tier = "Public" }

  tags = var.common_tags
}