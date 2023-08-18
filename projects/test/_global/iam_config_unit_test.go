package iam_team_test

import (
	"math/rand"
	"testing"
	"time"

	"github.com/dresspeng/infrastructure-modules/test/util"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	pathConfig = "../../module/_global/config"
)

func Test_Unit_Global_Config(t *testing.T) {
	// t.Parallel()
	rand.Seed(time.Now().UnixNano())

	id := util.RandomID(4)

	options := &terraform.Options{
		TerraformDir: pathConfig,
		Vars: map[string]any{
			"organization": map[string]any{
				"variables": []map[string]any{
					{
						"key":   "ORG_" + id,
						"value": "test",
					},
				},
				"secrets": []map[string]any{
					{
						"key":   "ORG_" + id,
						"value": "test",
					},
				},
			},

			"repositories": []map[string]any{
				{
					"accesses": []map[string]any{
						{
							"owner": "dresspeng",
							"name":  "infrastructure-modules",
						},
					},
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
	terratestStructure.RunTestStage(t, "validate", func() {})
}
