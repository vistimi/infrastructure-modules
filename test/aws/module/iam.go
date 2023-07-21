package module

import (
	"fmt"
	"testing"

	"github.com/KookaS/infrastructure-modules/test/util"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/iam"
	terratestAws "github.com/gruntwork-io/terratest/modules/aws"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func ValidateTeam(t *testing.T, accountRegion, teamName string, admins, devs, machines, resources []map[string]any) {
	terratestStructure.RunTestStage(t, "validate_team", func() {
		terratestStructure.RunTestStage(t, "validate_team_roles", func() {
			typeName := "resource-mutable"
			for _, roleName := range []string{"admin", "poweruser", "readonly"} {
				name := util.Format(typeName, roleName)
				resourceUserArn := TestRole(t, accountRegion, teamName, name, []string{})
				if resourceUserArn == nil {
					t.Fatalf("no resourceArn for resourceName: %s", name)
				}
				fmt.Println(aws.StringValue(resourceUserArn))
			}

			typeName = "resource-immutable"
			for _, roleName := range []string{"admin", "poweruser", "readonly"} {
				name := util.Format(typeName, roleName)
				resourceUserArn := TestRole(t, accountRegion, teamName, name, []string{})
				if resourceUserArn == nil {
					t.Fatalf("no resourceArn for resourceName: %s", name)
				}
				fmt.Println(aws.StringValue(resourceUserArn))
			}

			typeName = "machine"
			for _, roleName := range []string{"admin", "poweruser", "readonly"} {
				name := util.Format(typeName, roleName)
				resourceUserArn := TestRole(t, accountRegion, teamName, name, []string{"resource-mutable-poweruser", "resource-immutable-readonly"})
				if resourceUserArn == nil {
					t.Fatalf("no resourceArn for resourceName: %s", name)
				}
				fmt.Println(aws.StringValue(resourceUserArn))
			}

			typeName = "dev"
			for _, roleName := range []string{"admin", "poweruser"} {
				name := util.Format(typeName, roleName)
				resourceUserArn := TestRole(t, accountRegion, teamName, name, []string{"resource-mutable-poweruser", "resource-immutable-readonly", "machine-readonly"})
				if resourceUserArn == nil {
					t.Fatalf("no resourceArn for resourceName: %s", name)
				}
				fmt.Println(aws.StringValue(resourceUserArn))
			}

			typeName = "admin"
			for _, roleName := range []string{"admin", "poweruser"} {
				name := util.Format(typeName, roleName)
				resourceUserArn := TestRole(t, accountRegion, teamName, name, []string{"resource-mutable-admin", "resource-immutable-admin", "machine-admin", "dev-admin"})
				if resourceUserArn == nil {
					t.Fatalf("no resourceArn for resourceName: %s", name)
				}
				fmt.Println(aws.StringValue(resourceUserArn))
			}
		})

		terratestStructure.RunTestStage(t, "validate_team_groups", func() {
			groupName := "resource-mutable"
			mutableResources := util.Filter(resources, func(resource map[string]any) bool { return resource["mutable"].(bool) })
			mutableResourcesNames := util.Reduce(mutableResources, func(resource map[string]any) string { return resource["name"].(string) })
			groupArn := TestGroup(t, accountRegion, teamName, groupName, mutableResourcesNames)
			if groupArn == nil {
				t.Fatalf("no groupArn for groupName: %s", groupName)
			}
			fmt.Println(aws.StringValue(groupArn))

			groupName = "resource-immutable"
			immutableResources := util.Filter(resources, func(resource map[string]any) bool { return !resource["mutable"].(bool) })
			immutableResourcesNames := util.Reduce(immutableResources, func(resource map[string]any) string { return resource["name"].(string) })
			groupArn = TestGroup(t, accountRegion, teamName, groupName, immutableResourcesNames)
			if groupArn == nil {
				t.Fatalf("no groupArn for groupName: %s", groupName)
			}
			fmt.Println(aws.StringValue(groupArn))

			groupName = "machine"
			machineNames := util.Reduce(machines, func(resource map[string]any) string { return resource["name"].(string) })
			groupArn = TestGroup(t, accountRegion, teamName, groupName, machineNames)
			if groupArn == nil {
				t.Fatalf("no groupArn for groupName: %s", groupName)
			}
			fmt.Println(aws.StringValue(groupArn))

			groupName = "dev"
			devNames := util.Reduce(devs, func(resource map[string]any) string { return resource["name"].(string) })
			groupArn = TestGroup(t, accountRegion, teamName, groupName, devNames)
			if groupArn == nil {
				t.Fatalf("no groupArn for groupName: %s", groupName)
			}
			fmt.Println(aws.StringValue(groupArn))

			groupName = "admin"
			adminNames := util.Reduce(admins, func(resource map[string]any) string { return resource["name"].(string) })
			groupArn = TestGroup(t, accountRegion, teamName, groupName, adminNames)
			if groupArn == nil {
				t.Fatalf("no groupArn for groupName: %s", groupName)
			}
			fmt.Println(aws.StringValue(groupArn))
		})
	})
}

// func TestUser(t *testing.T, accountRegion, userName string) *string {
// 	iamClient, err := terratestAws.NewIamClientE(t, accountRegion)
// 	if err != nil {
// 		t.Fatal(err)
// 	}

// 	user, err := iamClient.GetUser(&iam.GetUserInput{UserName: aws.String(userName)})
// 	if err != nil {
// 		t.Fatal(err)
// 	}
// 	return user.User.Arn
// }

func TestGroup(t *testing.T, accountRegion, namePrefix, groupName string, userNames []string) *string {
	iamClient, err := terratestAws.NewIamClientE(t, accountRegion)
	if err != nil {
		t.Fatal(err)
	}

	group, err := iamClient.GetGroup(&iam.GetGroupInput{GroupName: aws.String(util.Format(namePrefix, groupName))})
	if err != nil {
		t.Fatal(err)
	}

	for _, user := range group.Users {
		util.Finds(t, userNames, []string{aws.StringValue(user.UserName)})
	}

	return group.Group.Arn
}

func TestRole(t *testing.T, accountRegion, namePrefix, roleName string, assumeRoleNames []string) *string {
	iamClient, err := terratestAws.NewIamClientE(t, accountRegion)
	if err != nil {
		t.Fatal(err)
	}

	role, err := iamClient.GetRole(&iam.GetRoleInput{RoleName: aws.String(util.Format(namePrefix, roleName))})
	if err != nil {
		t.Fatal(err)
	}

	for _, assumeRoleName := range assumeRoleNames {
		util.Find(t, assumeRoleName, aws.StringValue(role.Role.AssumeRolePolicyDocument))
	}

	return role.Role.Arn
}
