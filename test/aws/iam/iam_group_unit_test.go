package iam_team_test

import (
	"math/rand"
	"testing"
	"time"

	testAwsModule "github.com/KookaS/infrastructure-modules/test/aws/module"
	"github.com/KookaS/infrastructure-modules/test/util"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	pathGroup = "../../../module/aws/iam/group"
)

func Test_Unit_IAM_Group(t *testing.T) {
	// t.Parallel()
	rand.Seed(time.Now().UnixNano())

	teamName := "team" + util.RandomID(4)
	group := testAwsModule.GroupInfo{
		Name: "dev",
		Users: []map[string]any{{
			"name": "user1",
			"statements": []map[string]any{
				{
					"sid":       "user1Statement",
					"actions":   []string{"ec2:*"},
					"effect":    "Allow",
					"resources": []string{"*"},
				},
			},
		}},
		ExternalAssumeRoles: []string{},
		CreateAdminRole:     true,
		CreatePoweruserRole: true,
		CreateReadonlyRole:  true,
		AttachRoleName:      "poweruser",
	}

	groupStatements := []map[string]any{
		{
			"sid":       "groupStatement",
			"actions":   []string{"ecr:*"},
			"effect":    "Allow",
			"resources": []string{"*"},
		},
	}

	options := &terraform.Options{
		TerraformDir: pathGroup,
		Vars: map[string]any{
			"group_name": group.Name,

			"levels": []map[string]any{
				{
					"key":   "team",
					"value": teamName,
				},
			},

			"create_admin_role":         group.CreateAdminRole,
			"create_poweruser_role":     group.CreatePoweruserRole,
			"create_readonly_role":      group.CreateReadonlyRole,
			"pw_length":                 20,
			"users":                     group.Users,
			"statements":                groupStatements,
			"external_assume_role_arns": group.ExternalAssumeRoles,
			"store_secrets":             false,
			"tags":                      map[string]any{},
		},
	}

	defer func() {
		if r := recover(); r != nil {
			// destroy all resources if panic
			terraform.Destroy(t, options)
		}
		terratestStructure.RunTestStage(t, "cleanup", func() {
			terraform.Destroy(t, options)
		})
	}()

	terratestStructure.RunTestStage(t, "deploy", func() {
		terraform.InitAndApply(t, options)
	})
	terratestStructure.RunTestStage(t, "validate", func() {
		testAwsModule.ValidateGroup(t, util.GetEnvVariable("AWS_REGION_NAME"), teamName, group)
	})
}
