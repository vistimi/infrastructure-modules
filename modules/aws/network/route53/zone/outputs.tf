output "zone_id" {
  value = module.zones[*].route53_zone_zone_id
}

output "zone_arn" {
  value = module.zones[*].route53_zone_zone_arn
}

output "name_servers" {
  value = module.zones[*].route53_zone_name_servers
}

output "name" {
  value = module.zones[*].route53_zone_name
}
