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
	pathGroup = "../../../../module/aws/iam/group"
)

func Test_Unit_IAM_Group(t *testing.T) {
	// t.Parallel()
	rand.Seed(time.Now().UnixNano())

	teamName := "team" + util.RandomID(4)
	roleKey := "dev"
	admin := true
	poweruser := true
	readonly := true
	externalAssumeRoleNames := []string{}
	externalAssumeRoleArns := []string{}
	users := []map[string]any{{
		"name": "user1",
		// "statements": []map[string]any{
		// 	{
		// 		"sid":       "user1Statement",
		// 		"actions":   []string{"ecr:*"},
		// 		"effect":    "Allow",
		// 		"resources": []string{"*"},
		// 	},
		// },
	}}

	options := &terraform.Options{
		TerraformDir: pathGroup,
		Vars: map[string]any{
			"group_key": roleKey,

			"levels": []map[string]any{
				{
					"key":   "team",
					"value": teamName,
				},
			},

			"force_destroy": true,
			"admin":         admin,
			"poweruser":     poweruser,
			"readonly":      readonly,
			"pw_length":     20,
			"users":         users,
			"statements": []map[string]any{
				{
					"sid":       "groupStatement",
					"actions":   []string{"ec2:*"},
					"effect":    "Allow",
					"resources": []string{"*"},
				},
			},

			"external_assume_role_arns": externalAssumeRoleArns,
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
		testAwsModule.ValidateGroup(t, util.GetEnvVariable("AWS_REGION_NAME"), teamName, roleKey, admin, poweruser, readonly, externalAssumeRoleNames, users)
	})
}
