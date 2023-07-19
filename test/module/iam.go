package module

import (
	"testing"

	"github.com/KookaS/infrastructure-modules/test/util"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/iam"
	terratest_aws "github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratest_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func RunTestTeam(t *testing.T, options *terraform.Options, accountRegion string, adminNames, devNames, machineNames []string, repositoryName string) {
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
		repositoryUserArn := TestUserWithAssume(t, accountRegion, repositoryName, []string{})
		if repositoryUserArn == nil {
			t.Fatalf("no repositoryArn for repositoryName: %s", repositoryName)
		}

		// machineUserArns := []string{}
		for _, machineName := range machineNames {
			machineUserArn := TestUserWithAssume(t, accountRegion, machineName, []string{repositoryName})
			if machineUserArn == nil {
				t.Fatalf("no machineArn for machineName: %s", machineName)
			}
			// machineUserArns = append(machineUserArns, aws.StringValue(machineUserArn))
		}

		// devUserArns := []string{}
		for _, devName := range devNames {
			devUserArn := TestUserWithAssume(t, accountRegion, devName, append([]string{repositoryName}, machineNames...))
			if devUserArn == nil {
				t.Fatalf("no devArn for devName: %s", devName)
			}
			// devUserArns = append(devUserArns, aws.StringValue(devUserArn))
		}

		// adminUserArns := []string{}
		for _, adminName := range adminNames {
			adminUserArn := TestUserWithAssume(t, accountRegion, adminName, append([]string{repositoryName}, append(machineNames, devNames...)...))
			if adminUserArn == nil {
				t.Fatalf("no adminArn for adminName: %s", adminName)
			}
			// adminUserArns = append(adminUserArns, aws.StringValue(adminUserArn))
		}
	})
}

func TestUserWithAssume(t *testing.T, accountRegion, userName string, assumeRoleNames []string) *string {
	roleArn := TestRole(t, accountRegion, userName, assumeRoleNames)
	if roleArn == nil {
		t.Fatalf("no roleArn for userName: %s", userName)
	}

	return TestUser(t, accountRegion, userName)
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
