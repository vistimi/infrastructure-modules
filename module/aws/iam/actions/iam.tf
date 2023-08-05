locals {
  # https://docs.aws.amazon.com/service-authorization/latest/reference/list_awsidentityandaccessmanagementiam.html
  read = [
    "iam:GeneratiamedentialReport",
    "iam:GenerateOrganizationsAccessReport",
    "iam:GenerateServiceLastAccessedDetails",
    "iam:GetAccessKeyLastUsed",
    "iam:GetAccountAuthorizationDetails",
    "iam:GetAccountEmailAddress",
    "iam:GetAccountName",
    "iam:GetAccountPasswordPolicy",
    "iam:GetCloudFrontPublicKey",
    "iam:GetContextKeysForCustomPolicy",
    "iam:GetContextKeysForPrincipalPolicy",
    "iam:GetCredentialReport",
    "iam:GetGroup",
    "iam:GetGroupPolicy",
    "iam:GetInstanceProfile",
    "iam:GetMFADevice",
    "iam:GetOpenIDConnectProvider",
    "iam:GetOrganizationsAccessReport",
    "iam:GetPolicy",
    "iam:GetPolicyVersion",
    "iam:GetRole",
    "iam:GetRolePolicy",
    "iam:GetSAMLProvider",
    "iam:GetSSHPublicKey",
    "iam:GetServerCertificate",
    "iam:GetServiceLastAccessedDetails",
    "iam:GetServiceLastAccessedDetailsWithEntities",
    "iam:GetServiceLinkedRoleDeletionStatus",
    "iam:GetUser",
    "iam:GetUserPolicy",
    "iam:SimulateCustomPolicy",
    "iam:SimulatePrincipalPolicy",
  ]
  list = [
    "iam:GetAccountSummary",
    "iam:GetLoginProfile",
    "iam:ListAccessKeys",
    "iam:ListAccountAliases",
    "iam:ListAttachedGroupPolicies",
    "iam:ListAttachedRolePolicies",
    "iam:ListAttachedUserPolicies",
    "iam:ListCloudFrontPublicKeys",
    "iam:ListEntitiesForPolicy",
    "iam:ListGroupPolicies",
    "iam:ListGroups",
    "iam:ListGroupsForUser",
    "iam:ListInstanceProfileTags",
    "iam:ListInstanceProfiles",
    "iam:ListInstanceProfilesForRole",
    "iam:ListMFADeviceTags",
    "iam:ListMFADevices",
    "iam:ListOpenIDConnectProviderTags",
    "iam:ListOpenIDConnectProviders",
    "iam:ListPolicies",
    "iam:ListPoliciesGrantingServiceAccess",
    "iam:ListPolicyTags",
    "iam:ListPolicyVersions",
    "iam:ListRolePolicies",
    "iam:ListRoleTags",
    "iam:ListRoles",
    "iam:ListSAMLProviderTags",
    "iam:ListSAMLProviders",
    "iam:ListSSHPublicKeys",
    "iam:ListSTSRegionalEndpointsStatus",
    "iam:ListServerCertificateTags",
    "iam:ListServerCertificates",
    "iam:ListServiceSpecificCredentials",
    "iam:ListSigningCertificates",
    "iam:ListUserPolicies",
    "iam:ListUserTags",
    "iam:ListUsers",
    "iam:ListVirtualMFADevices",
  ]
  write = [
    "iam:AddClientIDToOpenIDConnectProvider",
    "iam:AddRoleToInstanceProfile",
    "iam:AddUserToGroup",
    "iam:ChangePassword",
    "iam:CreateAccessKey",
    "iam:CreateAccountAlias",
    "iam:CreateGroup",
    "iam:CreateInstanceProfile",
    "iam:CreateLoginProfile",
    "iam:CreateOpenIDConnectProvider",
    "iam:CreateRole",
    "iam:CreateSAMLProvider",
    "iam:CreateServiceLinkedRole",
    "iam:CreateServiceSpecificCredential",
    "iam:CreateUser",
    "iam:CreateVirtualMFADevice",
    "iam:DeactivateMFADevice",
    "iam:DeleteAccessKey",
    "iam:DeleteAccountAlias",
    "iam:DeleteCloudFrontPublicKey",
    "iam:DeleteGroup",
    "iam:DeleteInstanceProfile",
    "iam:DeleteLoginProfile",
    "iam:DeleteOpenIDConnectProvider",
    "iam:DeleteRole",
    "iam:DeleteSAMLProvider",
    "iam:DeleteSSHPublicKey",
    "iam:DeleteServerCertificate",
    "iam:DeleteServiceLinkedRole",
    "iam:DeleteServiceSpecificCredential",
    "iam:DeleteSigningCertificate",
    "iam:DeleteUser",
    "iam:DeleteVirtualMFADevice",
    "iam:EnableMFADevice",
    "iam:PassRole",
    "iam:RemoveClientIDFromOpenIDConnectProvider",
    "iam:RemoveRoleFromInstanceProfile",
    "iam:RemoveUserFromGroup",
    "iam:ResetServiceSpecificCredential",
    "iam:ResyncMFADevice",
    "iam:SetSTSRegionalEndpointStatus",
    "iam:SetSecurityTokenServicePreferences",
    "iam:UpdateAccessKey",
    "iam:UpdateAccountEmailAddress",
    "iam:UpdateAccountName",
    "iam:UpdateAccountPasswordPolicy",
    "iam:UpdateCloudFrontPublicKey",
    "iam:UpdateGroup",
    "iam:UpdateLoginProfile",
    "iam:UpdateOpenIDConnectProviderThumbprint",
    "iam:UpdateRole",
    "iam:UpdateRoleDescription",
    "iam:UpdateSAMLProvider",
    "iam:UpdateSSHPublicKey",
    "iam:UpdateServerCertificate",
    "iam:UpdateServiceSpecificCredential",
    "iam:UpdateSigningCertificate",
    "iam:UpdateUser",
    "iam:UploadCloudFrontPublicKey",
    "iam:UploadSSHPublicKey",
    "iam:UploadServerCertificate",
    "iam:UploadSigningCertificate",
  ]
  permission_management = [
    "iam:AttachGroupPolicy",
    "iam:AttachRolePolicy",
    "iam:AttachUserPolicy",
    "iam:CreatePolicy",
    "iam:CreatePolicyVersion",
    "iam:DeleteAccountPasswordPolicy",
    "iam:DeleteGroupPolicy",
    "iam:DeletePolicy",
    "iam:DeletePolicyVersion",
    "iam:DeleteRolePermissionsBoundary",
    "iam:DeleteRolePolicy",
    "iam:DeleteUserPermissionsBoundary",
    "iam:DeleteUserPolicy",
    "iam:DetachGroupPolicy",
    "iam:DetachRolePolicy",
    "iam:DetachUserPolicy",
    "iam:PutGroupPolicy",
    "iam:PutRolePermissionsBoundary",
    "iam:PutRolePolicy",
    "iam:PutUserPermissionsBoundary",
    "iam:PutUserPolicy",
    "iam:SetDefaultPolicyVersion",
    "iam:UpdateAssumeRolePolicy",
  ]
  tagging = [
    "iam:TagInstanceProfile",
    "iam:TagMFADevice",
    "iam:TagOpenIDConnectProvider",
    "iam:TagPolicy",
    "iam:TagRole",
    "iam:TagSAMLProvider",
    "iam:TagServerCertificate",
    "iam:TagUser",
    "iam:UntagInstanceProfile",
    "iam:UntagMFADevice",
    "iam:UntagOpenIDConnectProvider",
    "iam:UntagPolicy",
    "iam:UntagRole",
    "iam:UntagSAMLProvider",
    "iam:UntagServerCertificate",
    "iam:UntagUser",
  ]
}
