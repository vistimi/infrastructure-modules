locals {
  # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonelasticcontainerregistry.html
  read = [
    "ecr:BatchCheckLayerAvailability",
    "ecr:BatchGetImage",
    "ecr:BatchGetRepositoryScanningConfiguration",
    "ecr:DescribeImageReplicationStatus",
    "ecr:DescribeImageScanFindings",
    "ecr:DescribeRegistry",
    "ecr:DescribeRepositories",
    "ecr:GetAuthorizationToken",
    "ecr:GetDownloadUrlForLayer",
    "ecr:GetLifecyclePolicy",
    "ecr:GetLifecyclePolicyPreview",
    "ecr:GetRegistryPolicy",
    "ecr:GetRegistryScanningConfiguration",
    "ecr:GetRepositoryPolicy",
    "ecr:ListTagsForResource",
  ]
  list = [
    "ecr:DescribeImages",
    "ecr:DescribePullThroughCacheRules",
    "ecr:ListImages",
  ]
  write = [
    "ecr:BatchDeleteImage",
    "ecr:BatchImportUpstreamImage",
    "ecr:CompleteLayerUpload",
    "ecr:CreatePullThroughCacheRule",
    "ecr:CreateRepository",
    "ecr:DeleteLifecyclePolicy",
    "ecr:DeletePullThroughCacheRule",
    "ecr:DeleteRepository",
    "ecr:InitiateLayerUpload",
    "ecr:PutImage",
    "ecr:PutImageScanningConfiguration",
    "ecr:PutImageTagMutability",
    "ecr:PutLifecyclePolicy",
    "ecr:PutRegistryScanningConfiguration",
    "ecr:PutReplicationConfiguration",
    "ecr:ReplicateImage",
    "ecr:StartImageScan",
    "ecr:StartLifecyclePolicyPreview",
    "ecr:UploadLayerPart",
  ]
  permission_management = [
    "ecr:DeleteRegistryPolicy",
    "ecr:DeleteRepositoryPolicy",
    "ecr:PutRegistryPolicy",
    "ecr:SetRepositoryPolicy",
  ]
  tagging = [
    "ecr:TagResource",
    "ecr:UntagResource",
  ]
}
