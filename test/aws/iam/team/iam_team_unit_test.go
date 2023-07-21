package iam_team_test

import (
	"math/rand"
	"testing"
	"time"

	"github.com/KookaS/infrastructure-modules/test"
	testAwsModule "github.com/KookaS/infrastructure-modules/test/aws/module"
	"github.com/KookaS/infrastructure-modules/test/util"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	Path = "../../../../module/aws/iam/team"
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
		TerraformDir: Path,
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

	test.RunTest(t, options)
	terratestStructure.RunTestStage(t, "validate", func() {
		testAwsModule.ValidateTeam(t, util.GetEnvVariable("AWS_REGION_NAME"), id, admins, devs, machines, resources)
	})
}
