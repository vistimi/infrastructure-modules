
# create a group intended for administrators
resource "aws_iam_group" "administrators" {
  name = "Administrators"
  path = "/"
}

# read the ARN of the "AdministratorAccess," which is an AWS-managed policy
data "aws_iam_policy" "administrator_access" {
  name = "AdministratorAccess"
}

# attach the "AdministratorAccess" policy to the group
resource "aws_iam_group_policy_attachment" "administrators" {
  group      = aws_iam_group.administrators.name
  policy_arn = data.aws_iam_policy.administrator_access.arn
}

# create an admin user
resource "aws_iam_user" "administrator" {
  name = "Administrator"
}

# add that user to the admin group
resource "aws_iam_user_group_membership" "devstream" {
  user   = aws_iam_user.administrator.name
  groups = [aws_iam_group.administrators.name]
}

# enable console login for that admin user
resource "aws_iam_user_login_profile" "administrator" {
  user                    = aws_iam_user.administrator.name
  password_reset_required = true
}

# add the initial password as a sensitive output
output "password" {
  value     = aws_iam_user_login_profile.administrator.password
  sensitive = true
}