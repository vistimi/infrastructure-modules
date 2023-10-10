package iam_team_test

import (
	"math/rand"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/vistimi/infrastructure-modules/test/util"
)

const (
	path = "../../modules/github/variables"
)

var (
	accesses = []map[string]any{
		{
			"owner": "vistimi",
			"name":  "infrastructure-modules",
		},
	}
)

func Test_Unit_Global_Config(t *testing.T) {
	// t.Parallel()
	rand.Seed(time.Now().UnixNano())

	id := util.RandomID(4)

	options := &terraform.Options{
		TerraformDir: path,
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
					"accesses": accesses,
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

			"environments": []map[string]any{
				{
					"name":     id,
					"accesses": accesses,
					"variables": []map[string]any{
						{
							"key":   "ENV_" + id,
							"value": "test",
						},
					},
					"secrets": []map[string]any{
						{
							"key":   "ENV_" + id,
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
