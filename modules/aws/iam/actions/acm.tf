locals {
  # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonelasticcontainerregistry.html
  read = [
    "acm:DescribeCertificate",
    "acm:ExportCertificate",
    "acm:GetAccountConfiguration",
    "acm:GetCertificate",
    "acm:ListTagsForCertificate",
  ]
  list = [
    "acm:ListCertificates",
  ]
  write = [
    "acm:DeleteCertificate",
    "acm:ImportCertificate",
    "acm:PutAccountConfiguration",
    "acm:RenewCertificate",
    "acm:RequestCertificate",
    "acm:ResendValidationEmail",
    "acm:UpdateCertificateOptions",
  ]
  permission_management = []
  tagging = [
    "acm:AddTagsToCertificate",
    "acm:RemoveTagsFromCertificate",
  ]
}
