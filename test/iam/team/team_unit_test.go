package iam_team_test

import (
	"math/rand"
	"testing"
	"time"

	"github.com/KookaS/infrastructure-modules/test/module"
	"github.com/KookaS/infrastructure-modules/test/util"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

const (
	Path = "../../../module/aws/iam/team"
)

var (
	admins    = []map[string]any{{"name": "admin1"}}
	devs      = []map[string]any{{"name": "dev1"}}
	machines  = []map[string]any{{"name": "machine1"}}
	resources = []map[string]any{{"name": "res1-mut", "mutable": true}, {"name": "res2-immut", "mutable": false}}
)

func Test_Unit_IAM_Team(t *testing.T) {
	// t.Parallel()
	rand.Seed(time.Now().UnixNano())

	// id := util.RandomID(8)

	options := &terraform.Options{
		TerraformDir: Path,
		Vars: map[string]any{
			// "admin_names":    util.Appends(id, adminNames),
			// "dev_names":      util.Appends(id, devNames),
			// "resource_names": util.Appends(id, resourceNames),
			// "machine_names":  util.Appends(id, machineNames),
			"admins":    admins,
			"devs":      devs,
			"machines":  machines,
			"resources": resources,
		},
	}

	module.RunTestTeam(t, options, util.GetEnvVariable("AWS_REGION_NAME"), admins, devs, machines, resources)
}
