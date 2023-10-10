package iam_team_test

import (
	"math/rand"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
	testAwsModule "github.com/vistimi/infrastructure-modules/test/aws/module"
	"github.com/vistimi/infrastructure-modules/test/util"
)

const (
	pathLevel = "../../modules/_global/level"
)

func Test_Unit_Global_Level(t *testing.T) {
	// t.Parallel()
	rand.Seed(time.Now().UnixNano())

	namePrefix := ""
	id := util.RandomID(4)
	orgName := util.Format("-", "org", id)
	teamName := util.Format("-", "team", id)

	userStatements := []map[string]any{
		{
			"sid":       "userStatement",
			"actions":   []string{"ec2:*"},
			"effect":    "Allow",
			"resources": []string{"*"},
		},
	}
	groups := []testAwsModule.GroupInfo{
		{
			Name:                "admin",
			Users:               []map[string]any{{"name": "ad1", "statements": userStatements}},
			ExternalAssumeRoles: []string{},
		},
		{
			Name:                "dev",
			Users:               []map[string]any{{"name": "dev1"}},
			ExternalAssumeRoles: []string{},
		},
	}

	groupStatements := []map[string]any{
		{
			"sid":       "groupStatement",
			"actions":   []string{"ecr:*"},
			"effect":    "Allow",
			"resources": []string{"*"},
		},
	}

	groupsOptions := map[string]any{}
	for _, group := range groups {
		groupsOptions[group.Name] = map[string]any{
			"force_destroy": true,
			"pw_length":     20,
			"users":         group.Users,
			"statements":    groupStatements,
			"project_names": []string{"scraper"},
		}
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
			"name_prefix": namePrefix,
			"aws": map[string]any{
				"levels": []map[string]any{
					{
						"key":   "organization",
						"value": orgName,
					},
					{
						"key":   "team",
						"value": teamName,
					},
				},

				"groups": groupsOptions,

				"statements": levelStatements,

				"external_assume_role_arns": externalAssumeRoleArns,
				"store_secrets":             false,
				"tags":                      map[string]any{},
			},

			"github": map[string]any{
				"accesses": []map[string]any{
					{
						"owner": "vistimi",
						"name":  "infrastructure-modules",
					},
				},
				"repositories": []map[string]any{
					{
						"variables": []map[string]any{
							{
								"key":   "REPO_" + id,
								"value": "test",
							},
						},
						"secrets": []map[string]any{
							{
								"key":   "REPO_" + id,
								"value": "test",
							},
						},
					},
				},
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
		prefixName := util.Format("-", orgName, teamName)
		testAwsModule.ValidateLevel(t, util.GetEnvVariable("AWS_REGION_NAME"), prefixName, groups...)
	})
}
