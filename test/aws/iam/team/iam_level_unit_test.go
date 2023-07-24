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
	pathLevel = "../../../../module/aws/iam/level"
)

func Test_Unit_IAM_Level(t *testing.T) {
	// t.Parallel()
	rand.Seed(time.Now().UnixNano())

	orgName := "org123"   //+ util.RandomID(4)
	teamName := "team123" //+ util.RandomID(4)

	adminUsers := []map[string]any{{"name": "admin1"}}
	devUsers := []map[string]any{{"name": "dev1"}}
	machineUsers := []map[string]any{{"name": "machine1"}}
	resourceMutableUsers := []map[string]any{{"name": "res1-mut"}}
	resourceImmutableUsers := []map[string]any{{"name": "res2-immut"}}

	externalAssumeRoleArns := []string{}

	options := &terraform.Options{
		TerraformDir: pathLevel,
		Vars: map[string]any{
			"level_key":   "team",
			"level_value": teamName,
			"levels": []map[string]any{
				{
					"key":   "organization",
					"value": orgName,
				},
			},

			"groups": map[string]any{
				"admin": map[string]any{
					"force_destroy": true,
					"pw_length":     20,
					"users":         adminUsers,
					"statements": []map[string]any{
						{
							"sid":       "groupStatement",
							"actions":   []string{"ec2:*"},
							"effect":    "Allow",
							"resources": []string{"*"},
						},
					},
				},
				"dev": map[string]any{
					"force_destroy": true,
					"pw_length":     20,
					"users":         devUsers,
					"statements": []map[string]any{
						{
							"sid":       "groupStatement",
							"actions":   []string{"ec2:*"},
							"effect":    "Allow",
							"resources": []string{"*"},
						},
					},
				},
				"machine": map[string]any{
					"force_destroy": true,
					"pw_length":     20,
					"users":         machineUsers,
					"statements": []map[string]any{
						{
							"sid":       "groupStatement",
							"actions":   []string{"ec2:*"},
							"effect":    "Allow",
							"resources": []string{"*"},
						},
					},
				},
				"resource_mutable": map[string]any{
					"force_destroy": true,
					"pw_length":     20,
					"users":         resourceMutableUsers,
					"statements": []map[string]any{
						{
							"sid":       "groupStatement",
							"actions":   []string{"ec2:*"},
							"effect":    "Allow",
							"resources": []string{"*"},
						},
					},
				},
				"resource_immutable": map[string]any{
					"force_destroy": true,
					"pw_length":     20,
					"users":         resourceImmutableUsers,
					"statements": []map[string]any{
						{
							"sid":       "groupStatement",
							"actions":   []string{"ec2:*"},
							"effect":    "Allow",
							"resources": []string{"*"},
						},
					},
				},
			},

			"statements": []map[string]any{},

			"external_assume_role_arns": externalAssumeRoleArns,
			"store_secrets":             false,
			"tags":                      map[string]any{},
		},
	}

	// defer func() {
	// 	if r := recover(); r != nil {
	// 		// destroy all resources if panic
	// 		terraform.Destroy(t, options)
	// 	}
	// 	terratestStructure.RunTestStage(t, "cleanup", func() {
	// 		terraform.Destroy(t, options)
	// 	})
	// }()

	terratestStructure.RunTestStage(t, "deploy", func() {
		terraform.InitAndApply(t, options)
	})
	terratestStructure.RunTestStage(t, "validate", func() {
		prefixName := util.Format(orgName, teamName)
		testAwsModule.ValidateTeam(t, util.GetEnvVariable("AWS_REGION_NAME"), prefixName, adminUsers, devUsers, machineUsers, resourceMutableUsers, resourceImmutableUsers)
	})
}
