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
	pathLevel = "../../module/_global/level"
)

func Test_Unit_Global_Level(t *testing.T) {
	// t.Parallel()
	rand.Seed(time.Now().UnixNano())

	id := util.RandomID(4)

	orgName := "org" + id
	teamName := "team" + id

	userStatements := []map[string]any{
		{
			"sid":       "userStatement",
			"actions":   []string{"ec2:*"},
			"effect":    "Allow",
			"resources": []string{"*"},
		},
	}
	adminUsers := []map[string]any{{"name": "ad1", "statements": userStatements}}
	devUsers := []map[string]any{{"name": "dev1", "statements": userStatements}}
	machineUsers := []map[string]any{{"name": "machine1"}} // without statements for testing
	resourceMutableUsers := []map[string]any{{"name": "res1-mut", "statements": userStatements}}
	resourceImmutableUsers := []map[string]any{{"name": "res2-immut", "statements": userStatements}}

	groupStatements := []map[string]any{
		{
			"sid":       "groupStatement",
			"actions":   []string{"ecr:*"},
			"effect":    "Allow",
			"resources": []string{"*"},
		},
	}

	levelStatements := []map[string]any{
		{
			"sid":       "levelStatement",
			"actions":   []string{"s3:*"},
			"effect":    "Allow",
			"resources": []string{"*"},
			"conditions": []map[string]any{
				{
					"test":     "Bool",
					"variable": "aws:MultiFactorAuthPresent",
					"values":   []string{"true"},
				},
			},
		},
	}

	externalAssumeRoleArns := []string{}

	options := &terraform.Options{
		TerraformDir: pathLevel,
		Vars: map[string]any{
			"aws": map[string]any{
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
						"statements":    groupStatements,
					},
					"dev": map[string]any{
						"force_destroy": true,
						"pw_length":     20,
						"users":         devUsers,
						"statements":    groupStatements,
					},
					"machine": map[string]any{
						"force_destroy": true,
						"pw_length":     20,
						"users":         machineUsers,
						"statements":    groupStatements,
					},
					"resource-mutable": map[string]any{
						"force_destroy": true,
						"pw_length":     20,
						"users":         resourceMutableUsers,
						"statements":    groupStatements,
					},
					"resource-immutable": map[string]any{
						"force_destroy": true,
						"pw_length":     20,
						"users":         resourceImmutableUsers,
						"statements":    groupStatements,
					},
				},

				"statements": levelStatements,

				"external_assume_role_arns": externalAssumeRoleArns,
				"store_secrets":             false,
				"tags":                      map[string]any{},
			},

			"github": map[string]any{
				"repository_names":  []string{"dresspeng/infrastructure-modules"},
				"store_environment": true,
			},
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
		prefixName := util.Format(orgName, teamName)
		testAwsModule.ValidateLevel(t, util.GetEnvVariable("AWS_REGION_NAME"), prefixName, adminUsers, devUsers, machineUsers, resourceMutableUsers, resourceImmutableUsers)
	})
}
