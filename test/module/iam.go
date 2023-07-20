package module

import (
	"fmt"
	"testing"

	"github.com/KookaS/infrastructure-modules/test/util"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/iam"
	terratest_aws "github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratest_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func RunTestTeam(t *testing.T, options *terraform.Options, accountRegion string, adminNames, devNames, machineNames, resourceNames []string) {
	options = terraform.WithDefaultRetryableErrors(t, options)

	defer func() {
		if r := recover(); r != nil {
			// destroy all resources if panic
			terraform.Destroy(t, options)
		}
		terratest_structure.RunTestStage(t, "cleanup", func() {
			terraform.Destroy(t, options)
		})
	}()

	terratest_structure.RunTestStage(t, "deploy", func() {
		terraform.InitAndApply(t, options)
	})

	terratest_structure.RunTestStage(t, "validate", func() {

		typeName := "resource"
		for _, roleName := range []string{"admin", "poweruser", "readonly"} {
			name := typeName + "-" + roleName
			resourceUserArn := TestRole(t, accountRegion, name, []string{})
			if resourceUserArn == nil {
				t.Fatalf("no resourceArn for resourceName: %s", name)
			}
			fmt.Println(aws.StringValue(resourceUserArn))
		}

		typeName = "machine"
		for _, roleName := range []string{"admin", "poweruser", "readonly"} {
			name := typeName + "-" + roleName
			resourceUserArn := TestRole(t, accountRegion, name, []string{"resource-readonly"})
			if resourceUserArn == nil {
				t.Fatalf("no resourceArn for resourceName: %s", name)
			}
			fmt.Println(aws.StringValue(resourceUserArn))
		}

		typeName = "dev"
		for _, roleName := range []string{"admin", "poweruser"} {
			name := typeName + "-" + roleName
			resourceUserArn := TestRole(t, accountRegion, name, []string{"resource-readonly", "machine-readonly"})
			if resourceUserArn == nil {
				t.Fatalf("no resourceArn for resourceName: %s", name)
			}
			fmt.Println(aws.StringValue(resourceUserArn))
		}

		typeName = "admin"
		for _, roleName := range []string{"admin", "poweruser"} {
			name := typeName + "-" + roleName
			resourceUserArn := TestRole(t, accountRegion, name, []string{"resource-admin", "machine-admin", "dev-admin"})
			if resourceUserArn == nil {
				t.Fatalf("no resourceArn for resourceName: %s", name)
			}
			fmt.Println(aws.StringValue(resourceUserArn))
		}
	})
}

func TestUser(t *testing.T, accountRegion, userName string) *string {
	iamClient, err := terratest_aws.NewIamClientE(t, accountRegion)
	if err != nil {
		t.Fatal(err)
	}

	user, err := iamClient.GetUser(&iam.GetUserInput{UserName: aws.String(userName)})
	if err != nil {
		t.Fatal(err)
	}
	return user.User.Arn
}

func TestRole(t *testing.T, accountRegion, roleName string, assumeRoleNames []string) *string {
	iamClient, err := terratest_aws.NewIamClientE(t, accountRegion)
	if err != nil {
		t.Fatal(err)
	}

	role, err := iamClient.GetRole(&iam.GetRoleInput{RoleName: aws.String(roleName)})
	if err != nil {
		t.Fatal(err)
	}

	for _, assumeRoleName := range assumeRoleNames {
		util.Find(t, assumeRoleName, aws.StringValue(role.Role.AssumeRolePolicyDocument))
	}

	return role.Role.Arn
}
