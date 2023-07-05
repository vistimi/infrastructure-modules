data "aws_route53_zone" "selected" {
  name         = var.domain_name
  private_zone = true
}

module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "2.10.2"

  zone_id = data.aws_route53_zone.selected.zone_id

  # https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/ResourceRecordTypes.html
  records = [
    {
      name = var.subdomain_name
      type = "A"
      alias = {
        name    = var.alias_name
        zone_id = var.alias_zone_id
      }
    }
  ]

  provisioner "local-exec" {
    command = "sleep 10"
  }
}
