package module

import (
	"testing"

	"github.com/KookaS/infrastructure-modules/test/util"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/iam"
	terratestAws "github.com/gruntwork-io/terratest/modules/aws"
	terratestLogger "github.com/gruntwork-io/terratest/modules/logger"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func ValidateTeam(t *testing.T, accountRegion, teamName string, adminUsers, devUsers, machineUsers, resourceMutableUsers, resourceImmutableUsers []map[string]any) {
	terratestStructure.RunTestStage(t, "validate_team", func() {

		roleKey := "resource-mutable"
		policyElementNames := []string{}
		admin := true
		// poweruser := true
		readonly := false
		ValidateGroup(t, accountRegion, teamName, roleKey, admin, readonly, policyElementNames, resourceMutableUsers)

		roleKey = "resource-immutable"
		policyElementNames = []string{}
		admin = true
		// poweruser = true
		readonly = true
		ValidateGroup(t, accountRegion, teamName, roleKey, admin, readonly, policyElementNames, resourceImmutableUsers)

		roleKey = "machine"
		policyElementNames = []string{"resource-mutable-poweruser", "resource-immutable-readonly"}
		admin = true
		// poweruser = true
		readonly = false
		ValidateGroup(t, accountRegion, teamName, roleKey, admin, readonly, policyElementNames, machineUsers)

		roleKey = "dev"
		policyElementNames = []string{"resource-mutable-poweruser", "resource-immutable-readonly", "machine-readonly"}
		admin = true
		// poweruser = true
		readonly = false
		ValidateGroup(t, accountRegion, teamName, roleKey, admin, readonly, policyElementNames, devUsers)

		roleKey = "admin"
		policyElementNames = []string{"resource-mutable-admin", "resource-immutable-admin", "machine-admin", "dev-admin"}
		admin = true
		// poweruser = false
		readonly = false
		ValidateGroup(t, accountRegion, teamName, roleKey, admin, readonly, policyElementNames, adminUsers)
	})
}

func ValidateGroup(t *testing.T, accountRegion, prefixName, roleKey string, admin, readonly bool, policyElementNames []string, users []map[string]any) {
	terratestStructure.RunTestStage(t, "validate_group", func() {
		terratestStructure.RunTestStage(t, "validate_group_role", func() {
			var accessRoleNames []string
			if admin {
				accessRoleNames = append(accessRoleNames, "admin")
			}
			if true {
				accessRoleNames = append(accessRoleNames, "poweruser")
			}
			if readonly {
				accessRoleNames = append(accessRoleNames, "readonly")
			}
			for _, accessRoleName := range accessRoleNames {
				groupName := util.Format(prefixName, roleKey, accessRoleName)
				groupRoleArn := TestRole(t, accountRegion, groupName)
				if groupRoleArn == nil {
					t.Fatalf("no groupRoleArn for groupName: %s", groupName)
				}
			}
		})

		terratestStructure.RunTestStage(t, "validate_group_permissions", func() {
			userNames := util.Reduce(users, func(resource map[string]any) string { return resource["name"].(string) })
			groupName := util.Format(prefixName, roleKey)
			groupArn := TestGroup(t, accountRegion, groupName, userNames, policyElementNames)
			if groupArn == nil {
				t.Fatalf("no groupArn for groupName: %s", groupName)
			}

			for _, userName := range userNames {
				userName := util.Format(groupName, userName)
				userArn := TestUser(t, accountRegion, userName)
				if userArn == nil {
					t.Fatalf("no userArn for userName: %s", userName)
				}

				// TODO: test each user role
			}
		})
	})
}

func TestUser(t *testing.T, accountRegion, userName string) *string {
	iamClient, err := terratestAws.NewIamClientE(t, accountRegion)
	if err != nil {
		t.Fatal(err)
	}

	terratestLogger.Log(t, "user:: "+userName)
	user, err := iamClient.GetUser(&iam.GetUserInput{UserName: aws.String(userName)})
	if err != nil {
		t.Fatal(err)
	}
	return user.User.Arn
}

func TestGroup(t *testing.T, accountRegion, groupName string, userNames []string, assumeRoleNames []string) *string {
	iamClient, err := terratestAws.NewIamClientE(t, accountRegion)
	if err != nil {
		t.Fatal(err)
	}

	terratestLogger.Log(t, "group users:: "+groupName)
	group, err := iamClient.GetGroup(&iam.GetGroupInput{GroupName: aws.String(groupName)})
	if err != nil {
		t.Fatal(err)
	}

	for _, user := range group.Users {
		util.Finds(t, userNames, []string{aws.StringValue(user.UserName)})
	}

	// FIXME: not found
	// terratestLogger.Log(t, "group policy:: "+groupName)
	// groupPolicy, err := iamClient.GetGroupPolicy(&iam.GetGroupPolicyInput{GroupName: aws.String(groupName), PolicyName: aws.String(groupName)})
	// if err != nil {
	// 	t.Fatal(err)
	// }

	// for _, assumeRoleName := range assumeRoleNames {
	// 	util.Find(t, assumeRoleName, aws.StringValue(groupPolicy.PolicyDocument))
	// }

	return group.Group.Arn
}

func TestRole(t *testing.T, accountRegion, roleName string) *string {
	iamClient, err := terratestAws.NewIamClientE(t, accountRegion)
	if err != nil {
		t.Fatal(err)
	}

	terratestLogger.Log(t, "role:: "+roleName)
	role, err := iamClient.GetRole(&iam.GetRoleInput{RoleName: aws.String(util.Format(roleName))})
	if err != nil {
		t.Fatal(err)
	}

	return role.Role.Arn
}
