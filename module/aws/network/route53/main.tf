# https://github.com/terraform-aws-modules/terraform-aws-route53/blob/master/examples/complete/main.tf

locals {
  zone_name = var.zone.name
}

module "zone" {
  source = "./zone"

  vpc_id  = var.vpc_id
  name    = local.zone_name
  comment = var.zone.comment

  tags = var.tags
}

module "record" {
  source = "./record"

  zone_name      = local.zone_name
  subdomain_name = var.record.subdomain_name
  alias_name     = var.record.alias_name
  alias_zone_id  = var.record.alias_zone_id

  depends_on = [module.zone]
}
