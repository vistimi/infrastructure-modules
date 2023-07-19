package module

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

func SetupOptionsMicroservice(t *testing.T, projectName, serviceName string) {
	rand.Seed(time.Now().UnixNano())

	options := &terraform.Options{
		TerraformDir: Path,
		Vars: map[string]any{
			"admin_names":     adminNames,
			"dev_names":       devNames,
			"repository_name": repositoryName,
			"machine_names":   machineNames,
		},
	}

	module.RunTestTeam(t, options, util.GetEnvVariable("AWS_REGION_NAME"), adminNames, devNames, machineNames, repositoryName)
}
