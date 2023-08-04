package module

import (
	"testing"

	"github.com/dresspeng/infrastructure-modules/test/util"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/iam"
	terratestAws "github.com/gruntwork-io/terratest/modules/aws"
	terratestLogger "github.com/gruntwork-io/terratest/modules/logger"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

type GroupInfo struct {
	Name                string
	Users               []map[string]any
	ExternalAssumeRoles []string
}

func ValidateLevel(t *testing.T, accountRegion, prefixName string, groups ...GroupInfo) {
	terratestStructure.RunTestStage(t, "validate_level", func() {
		for _, group := range groups {
			ValidateGroup(t, accountRegion, prefixName, group)
		}
	})
}

func ValidateGroup(t *testing.T, accountRegion, prefixName string, group GroupInfo) {
	terratestStructure.RunTestStage(t, "validate_group", func() {
		terratestStructure.RunTestStage(t, "validate_group_role", func() {
			accessRoleNames := group.ExternalAssumeRoles

			for _, accessRoleName := range accessRoleNames {
				groupName := util.Format(prefixName, group.Name, accessRoleName)
				groupRoleArn := TestRole(t, accountRegion, groupName)
				if groupRoleArn == nil {
					t.Fatalf("no groupRoleArn for groupName: %s", groupName)
				}
			}
		})

		terratestStructure.RunTestStage(t, "validate_group_permissions", func() {
			userNames := util.Reduce(group.Users, func(resource map[string]any) string { return resource["name"].(string) })
			groupName := util.Format(prefixName, group.Name)
			groupArn := TestGroup(t, accountRegion, groupName, userNames)
			if groupArn == nil {
				t.Fatalf("no groupArn for groupName: %s", groupName)
			}

			for _, userName := range userNames {
				// userName := util.Format(groupName, userName)
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

func TestGroup(t *testing.T, accountRegion, groupName string, userNames []string) *string {
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
