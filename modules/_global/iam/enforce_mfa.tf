# customer-managed policy
data "aws_iam_policy_document" "enforce_mfa" {
  statement {
    sid    = "DenyAllExceptListedIfNoMFA"
    effect = "Deny"
    not_actions = [
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:GetUser",
      "iam:ListMFADevices",
      "iam:ListVirtualMFADevices",
      "iam:ResyncMFADevice",
      "sts:GetSessionToken"
    ]
    resources = ["*"]
    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false", ]
    }
  }
}

# enforce mfa to all users
resource "aws_iam_policy" "enforce_mfa" {
  name        = "enforce-to-use-mfa"
  path        = "/"
  description = "Policy to allow MFA management"
  policy      = data.aws_iam_policy_document.enforce_mfa.json
}

# # administrator group must enable MFA
# resource "aws_iam_group_policy_attachment" "enforce_mfa" {
#   group      = aws_iam_group.administrators.name
#   policy_arn = aws_iam_policy.enforce_mfa.arn
# }