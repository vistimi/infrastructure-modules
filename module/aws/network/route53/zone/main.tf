# data "aws_route53_zone" "selected" {
#   name         = var.name
#   private_zone = true
# }

# TODO: make zone NS correspond to the domain NS 
module "zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "2.10.2"

  # for_each = { for zone in setsubtract([var.name], [data.aws_route53_zone.selected.name]) :
  for_each = { for zone in [var.name] :
    zone => {
      comment = var.comment
      vpc = [
        {
          vpc_id = var.vpc_id
        }
      ]
      tags = var.tags
    }
  }

  # only create non existing zones
  zones = { each.key = each.value }

  provisioner "local-exec" {
    command = "sleep 10"
  }

  tags = var.tags
}
