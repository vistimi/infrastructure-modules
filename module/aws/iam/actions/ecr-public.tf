locals {
  # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonelasticcontainerregistrypublic.html
  read = [
    "ecr-public:BatchCheckLayerAvailability",
    "ecr-public:DescribeImages",
    "ecr-public:GetAuthorizationToken",
    "ecr-public:GetRegistryCatalogData",
    "ecr-public:GetRepositoryCatalogData",
    "ecr-public:GetRepositoryPolicy",
    "ecr-public:ListTagsForResource",
  ]
  list = [
    "ecr-public:DescribeImageTags",
    "ecr-public:DescribeRegistries",
    "ecr-public:DescribeRepositories",
  ]
  write = [
    "ecr-public:BatchDeleteImage",
    "ecr-public:CompleteLayerUpload",
    "ecr-public:CreateRepository",
    "ecr-public:DeleteRepository",
    "ecr-public:DeleteRepositoryPolicy",
    "ecr-public:InitiateLayerUpload",
    "ecr-public:PutImage",
    "ecr-public:PutRegistryCatalogData",
    "ecr-public:PutRepositoryCatalogData",
    "ecr-public:UploadLayerPart",
  ]
  permission_management = [
    "ecr-public:SetRepositoryPolicy",
  ]
  tagging = [
    "ecr-public:TagResource",
    "ecr-public:UntagResource",
  ]
}
