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
	adminNames    = []string{"admin1"}
	devNames      = []string{"dev1"}
	resourceNames = []string{"repo1"}
	machineNames  = []string{"machine1"}
)

func Test_Unit_IAM_Team(t *testing.T) {
	// t.Parallel()
	rand.Seed(time.Now().UnixNano())

	id := util.RandomID(8)

	options := &terraform.Options{
		TerraformDir: Path,
		Vars: map[string]any{
			"admin_names":    util.Appends(id, adminNames),
			"dev_names":      util.Appends(id, devNames),
			"resource_names": util.Appends(id, resourceNames),
			"machine_names":  util.Appends(id, machineNames),
		},
	}

	module.RunTestTeam(t, options, util.GetEnvVariable("AWS_REGION_NAME"), adminNames, devNames, machineNames, resourceNames)
}
