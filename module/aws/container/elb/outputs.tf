# https://registry.terraform.io/module/terraform-aws-modules/elb/aws/8.6.0?utm_content=documentLink&utm_medium=Visual+Studio+Code&utm_source=terraform-ls#outputs
output "elb" {
  value = {
    http_tcp_listener_arns    = module.elb.http_tcp_listener_arns
    http_tcp_listener_ids     = module.elb.http_tcp_listener_ids
    https_listener_arns       = module.elb.https_listener_arns
    https_listener_ids        = module.elb.https_listener_ids
    lb_arn                    = module.elb.lb_arn
    lb_arn_suffix             = module.elb.lb_arn_suffix
    lb_dns_name               = module.elb.lb_dns_name
    lb_id                     = module.elb.lb_id
    lb_zone_id                = module.elb.lb_zone_id
    security_group_arn        = module.elb.security_group_arn
    security_group_id         = module.elb.security_group_id
    target_group_arn_suffixes = module.elb.target_group_arn_suffixes
    target_group_arns         = module.elb.target_group_arns
    target_group_attachments  = module.elb.target_group_attachments
    target_group_names        = module.elb.target_group_names
  }
}

output "elb_sg" {
  value = {
    security_group_id = module.elb_sg.security_group_id
  }
}
