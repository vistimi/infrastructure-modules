output "azs" {
  value = module.vpc.azs
}

output "cgw" {
  value = {
    arns = module.vpc.cgw_arns
    ids  = module.vpc.cgw_ids
  }
}

output "database" {
  value = {
    internet_gateway_route_id   = module.vpc.database_internet_gateway_route_id
    ipv6_egress_route_id        = module.vpc.database_ipv6_egress_route_id
    nat_gateway_route_ids       = module.vpc.database_nat_gateway_route_ids
    network_acl_arn             = module.vpc.database_network_acl_arn
    network_acl_id              = module.vpc.database_network_acl_id
    route_table_association_ids = module.vpc.database_route_table_association_ids
    route_table_ids             = module.vpc.database_route_table_ids
    subnet_arns                 = module.vpc.database_subnet_arns
    subnet_group                = module.vpc.database_subnet_group
    subnet_group_name           = module.vpc.database_subnet_group_name
    subnets                     = module.vpc.database_subnets
    subnets_cidr_blocks         = module.vpc.database_subnets_cidr_blocks
    subnets_ipv6_cidr_blocks    = module.vpc.database_subnets_ipv6_cidr_blocks
  }
}

output "default" {
  value = {
    network_acl_id                = module.vpc.default_network_acl_id
    route_table_id                = module.vpc.default_route_table_id
    security_group_id             = module.vpc.default_security_group_id
    vpc_arn                       = module.vpc.default_vpc_arn
    vpc_cidr_block                = module.vpc.default_vpc_cidr_block
    vpc_default_network_acl_id    = module.vpc.default_vpc_default_network_acl_id
    vpc_default_route_table_id    = module.vpc.default_vpc_default_route_table_id
    vpc_default_security_group_id = module.vpc.default_vpc_default_security_group_id
    vpc_enable_dns_hostnames      = module.vpc.default_vpc_enable_dns_hostnames
    vpc_enable_dns_support        = module.vpc.default_vpc_enable_dns_support
    vpc_id                        = module.vpc.default_vpc_id
    vpc_instance_tenancy          = module.vpc.default_vpc_instance_tenancy
    vpc_main_route_table_id       = module.vpc.default_vpc_main_route_table_id
  }
}

output "dhcp" {
  value = {
    options_id = module.vpc.dhcp_options_id
  }
}

output "egress" {
  value = {
    only_internet_gateway_id = module.vpc.egress_only_internet_gateway_id
  }
}

output "elasticache" {
  value = {
    network_acl_arn             = module.vpc.elasticache_network_acl_arn
    network_acl_id              = module.vpc.elasticache_network_acl_id
    route_table_association_ids = module.vpc.elasticache_route_table_association_ids
    route_table_ids             = module.vpc.elasticache_route_table_ids
    subnet_arns                 = module.vpc.elasticache_subnet_arns
    subnet_group                = module.vpc.elasticache_subnet_group
    subnet_group_name           = module.vpc.elasticache_subnet_group_name
    subnets                     = module.vpc.elasticache_subnets
    subnets_cidr_blocks         = module.vpc.elasticache_subnets_cidr_blocks
    subnets_ipv6_cidr_blocks    = module.vpc.elasticache_subnets_ipv6_cidr_blocks
  }
}

output "igw" {
  value = {
    arn = module.vpc.igw_arn
    id  = module.vpc.igw_id
  }
}

output "intra" {
  value = {
    network_acl_arn             = module.vpc.intra_network_acl_arn
    network_acl_id              = module.vpc.intra_network_acl_id
    route_table_association_ids = module.vpc.intra_route_table_association_ids
    route_table_ids             = module.vpc.intra_route_table_ids
    subnet_arns                 = module.vpc.intra_subnet_arns
    subnets                     = module.vpc.intra_subnets
    subnets_cidr_blocks         = module.vpc.intra_subnets_cidr_blocks
    subnets_ipv6_cidr_blocks    = module.vpc.intra_subnets_ipv6_cidr_blocks
  }
}

output "name" {
  value = module.vpc.name
}

output "nat" {
  value = {
    ids        = module.vpc.nat_ids
    public_ips = module.vpc.nat_public_ips
    gw_ids     = module.vpc.natgw_ids
  }
}

output "outpost" {
  value = {
    network_acl_arn          = module.vpc.outpost_network_acl_arn
    network_acl_id           = module.vpc.outpost_network_acl_id
    subnet_arns              = module.vpc.outpost_subnet_arns
    subnets                  = module.vpc.outpost_subnets
    subnets_cidr_blocks      = module.vpc.outpost_subnets_cidr_blocks
    subnets_ipv6_cidr_blocks = module.vpc.outpost_subnets_ipv6_cidr_blocks
  }
}

output "private" {
  value = {
    ipv6_egress_route_ids       = module.vpc.private_ipv6_egress_route_ids
    nat_gateway_route_ids       = module.vpc.private_nat_gateway_route_ids
    network_acl_arn             = module.vpc.private_network_acl_arn
    network_acl_id              = module.vpc.private_network_acl_id
    route_table_association_ids = module.vpc.private_route_table_association_ids
    route_table_ids             = module.vpc.private_route_table_ids
    subnet_arns                 = module.vpc.private_subnet_arns
    subnets                     = module.vpc.private_subnets
    subnets_cidr_blocks         = module.vpc.private_subnets_cidr_blocks
    subnets_ipv6_cidr_blocks    = module.vpc.private_subnets_ipv6_cidr_blocks
  }
}

output "public" {
  value = {
    internet_gateway_ipv6_route_id = module.vpc.public_internet_gateway_ipv6_route_id
    internet_gateway_route_id      = module.vpc.public_internet_gateway_route_id
    network_acl_arn                = module.vpc.public_network_acl_arn
    network_acl_id                 = module.vpc.public_network_acl_id
    route_table_association_ids    = module.vpc.public_route_table_association_ids
    route_table_ids                = module.vpc.public_route_table_ids
    subnet_arns                    = module.vpc.public_subnet_arns
    subnets                        = module.vpc.public_subnets
    subnets_cidr_blocks            = module.vpc.public_subnets_cidr_blocks
    subnets_ipv6_cidr_blocks       = module.vpc.public_subnets_ipv6_cidr_blocks
  }
}

output "redshift" {
  value = {
    network_acl_arn                    = module.vpc.redshift_network_acl_arn
    network_acl_id                     = module.vpc.redshift_network_acl_id
    public_route_table_association_ids = module.vpc.redshift_public_route_table_association_ids
    route_table_association_ids        = module.vpc.redshift_route_table_association_ids
    route_table_ids                    = module.vpc.redshift_route_table_ids
    subnet_arns                        = module.vpc.redshift_subnet_arns
    subnet_group                       = module.vpc.redshift_subnet_group
    subnets                            = module.vpc.redshift_subnets
    subnets_cidr_blocks                = module.vpc.redshift_subnets_cidr_blocks
    subnets_ipv6_cidr_blocks           = module.vpc.redshift_subnets_ipv6_cidr_blocks
  }
}

output "this_customer_gateway" {
  value = module.vpc.this_customer_gateway
}

output "vgw" {
  value = {
    arn = module.vpc.vgw_arn
    id  = module.vpc.vgw_id
  }
}

output "vpc" {
  value = {
    arn                              = module.vpc.vpc_arn
    cidr_block                       = module.vpc.vpc_cidr_block
    enable_dns_hostnames             = module.vpc.vpc_enable_dns_hostnames
    enable_dns_support               = module.vpc.vpc_enable_dns_support
    flow_log_cloudwatch_iam_role_arn = module.vpc.vpc_flow_log_cloudwatch_iam_role_arn
    flow_log_destination_arn         = module.vpc.vpc_flow_log_destination_arn
    flow_log_destination_type        = module.vpc.vpc_flow_log_destination_type
    flow_log_id                      = module.vpc.vpc_flow_log_id
    id                               = module.vpc.vpc_id
    instance_tenancy                 = module.vpc.vpc_instance_tenancy
    ipv6_association_id              = module.vpc.vpc_ipv6_association_id
    ipv6_cidr_block                  = module.vpc.vpc_ipv6_cidr_block
    main_route_table_id              = module.vpc.vpc_main_route_table_id
    owner_id                         = module.vpc.vpc_owner_id
    secondary_cidr_blocks            = module.vpc.vpc_secondary_cidr_blocks
  }
}
