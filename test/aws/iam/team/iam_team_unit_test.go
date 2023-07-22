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
	PathTeam = "../../../../module/aws/iam/team"
)

func Test_Unit_IAM_Team(t *testing.T) {
	// t.Parallel()
	rand.Seed(time.Now().UnixNano())

	id := util.RandomID(8)

	admins := []map[string]any{{"name": "admin1"}}
	devs := []map[string]any{{"name": "dev1"}}
	machines := []map[string]any{{"name": "machine1"}}
	resources := []map[string]any{{"name": "res1-mut", "mutable": true}, {"name": "res2-immut", "mutable": false}}

	options := &terraform.Options{
		TerraformDir: PathTeam,
		Vars: map[string]any{
			"name": id,

			"admins":    admins,
			"devs":      devs,
			"machines":  machines,
			"resources": resources,

			"store_secrets": false,
			"tags":          map[string]any{},
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
		testAwsModule.ValidateTeam(t, util.GetEnvVariable("AWS_REGION_NAME"), id, admins, devs, machines, resources)
	})
}
