locals {
  # https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/5.1.1?utm_content=documentLink&utm_medium=Visual+Studio+Code&utm_source=terraform-ls#private-versus-intra-subnets
  tier_tags = ["private", "public", "intra"]

  # increment from `0.0.0.0/16` to `0.0.16.0/16`
  azs = try(slice(data.aws_availability_zones.available.names, 0, var.az_max), data.aws_availability_zones.available.names)
  subnets = {
    for i, tier in local.tier_tags :
    "${tier}" => [for az_idx in range(0, length(local.azs)) : cidrsubnet(var.cidr_ipv4, 4, i * length(local.azs) + az_idx)]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.name
  cidr = var.cidr_ipv4

  map_public_ip_on_launch = true # eks

  # https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/5.1.1?utm_content=documentLink&utm_medium=Visual+Studio+Code&utm_source=terraform-ls#nat-gateway-scenarios
  enable_nat_gateway     = var.nat != null ? true : false
  single_nat_gateway     = var.nat == "vpc" ? true : false
  one_nat_gateway_per_az = var.nat == "az" ? true : false

  azs             = data.aws_availability_zones.available.names
  public_subnets  = local.subnets["public"]
  private_subnets = local.subnets["private"]
  intra_subnets   = local.subnets["intra"]

  private_subnet_tags = { Tier = "private" }
  public_subnet_tags  = { Tier = "public" }
  intra_subnet_tags   = { Tier = "intra" }

  tags = merge(var.tags, { Zones = jsonencode(data.aws_availability_zones.available.names) })
}
