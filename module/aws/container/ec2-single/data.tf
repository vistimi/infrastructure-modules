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

locals {
  account_id  = data.aws_caller_identity.current.account_id
  account_arn = data.aws_caller_identity.current.arn
  dns_suffix  = data.aws_partition.current.dns_suffix // amazonaws.com
  partition   = data.aws_partition.current.partition  // aws
  region      = data.aws_region.current.name
  subnets     = data.aws_subnets.tier.ids
}
