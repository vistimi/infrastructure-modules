output "zone" {
  value = {
    for key, zone in module.zone : key => {
      id           = zone.zone_id
      arn          = zone.zone_arn
      name_servers = zone.name_servers
      name         = zone.name
    }
  }
}

output "record" {
  value = {
    name = module.record.name
    fqdn = module.record.fqdn
  }
}
