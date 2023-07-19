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
	adminNames     = []string{"admin1"}
	devNames       = []string{"dev1"}
	repositoryName = "repo1"
	machineNames   = []string{"machine1"}
)

func Test_Unit_IAM_Team(t *testing.T) {
	// t.Parallel()
	rand.Seed(time.Now().UnixNano())

	id := util.RandomID(8)

	options := &terraform.Options{
		TerraformDir: Path,
		Vars: map[string]any{
			"admin_names":     util.AppendIDs(id, adminNames),
			"dev_names":       util.AppendIDs(id, devNames),
			"repository_name": util.AppendID(id, repositoryName),
			"machine_names":   util.AppendIDs(id, machineNames),
		},
	}

	module.RunTestTeam(t, options, util.GetEnvVariable("AWS_REGION_NAME"), adminNames, devNames, machineNames, repositoryName)
}

func IntMin(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func TestIntMinBasic(t *testing.T) {
	ans := IntMin(2, -2)
	if ans != -2 {
		t.Errorf("IntMin(2, -2) = %d; want -2", ans)
	}
}
