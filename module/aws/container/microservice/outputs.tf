output "ecs" {
  value = {
    elb     = module.ecs.elb
    acm     = module.ecs.acm
    route53 = module.ecs.route53
    asg     = module.ecs.asg
    cluster = module.ecs.cluster
    service = module.ecs.service
  }
}

output "vpc" {
  value = {
    azs                   = module.vpc.azs
    cgw                   = module.vpc.cgw
    database              = module.vpc.database
    default               = module.vpc.default
    dhcp                  = module.vpc.dhcp
    egress                = module.vpc.egress
    elasticache           = module.vpc.elasticache
    igw                   = module.vpc.igw
    intra                 = module.vpc.intra
    name                  = module.vpc.name
    nat                   = module.vpc.nat
    outpost               = module.vpc.outpost
    private               = module.vpc.private
    public                = module.vpc.public
    redshift              = module.vpc.redshift
    this_customer_gateway = module.vpc.this_customer_gateway
    vgw                   = module.vpc.vgw
    vpc                   = module.vpc.vpc
  }
}

output "bucket_env" {
  value = { for key, value in module.bucket_env : key => value.bucket }
}
