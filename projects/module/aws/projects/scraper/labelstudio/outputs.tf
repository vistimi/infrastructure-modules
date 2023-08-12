output "labelstudio" {
  value = {
    cluster_name       = module.labelstudio.cluster_name
    cluster_version    = module.labelstudio.cluster_version
    cluster_endpoint   = module.labelstudio.cluster_endpoint
    bucket_id          = module.labelstudio.bucket_id
    connect_cluster    = module.labelstudio.connect_cluster
    load_balancer_host = module.labelstudio.load_balancer_host
    host               = module.labelstudio.host
  }
}

output "kms" {
  value = {
    key_arn                       = module.kms.key_arn
    key_id                        = module.kms.key_id
    key_policy                    = module.kms.key_policy
    external_key_expiration_model = module.kms.external_key_expiration_model
    external_key_state            = module.kms.external_key_state
    external_key_usage            = module.kms.external_key_usage
    aliases                       = module.kms.aliases
    grants                        = module.kms.grants
  }
}

output "bucket_label" {
  value = module.bucket_label
}
