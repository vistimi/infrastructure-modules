package module

import (
	"fmt"
	"math/rand"
	"strings"
	"testing"
	"time"

	"github.com/dresspeng/infrastructure-modules/test/util"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

var (
	AccountName   = util.GetEnvVariable("AWS_PROFILE_NAME")
	AccountId     = util.GetEnvVariable("AWS_ACCOUNT_ID")
	AccountRegion = util.GetEnvVariable("AWS_REGION_NAME")
	DomainName    = fmt.Sprintf("%s.%s", util.GetEnvVariable("DOMAIN_NAME"), util.GetEnvVariable("DOMAIN_SUFFIX"))
)

const (
	// https://docs.aws.amazon.com/AmazonECS/latest/developerguide/memory-management.html#ecs-reserved-memory
	ECSReservedMemory = 100
)

func SetupOptionsMicroserviceWrapper(t *testing.T, projectName, serviceName string) (*terraform.Options, string) {
	rand.Seed(time.Now().UnixNano())

	// global variables
	namePrefix := "vi"
	id := util.RandomID(4)
	nameSuffix := strings.ToLower(util.Format("-", util.GetEnvVariable("AWS_PROFILE_NAME"), id))
	tags := map[string]string{
		"TestID":  id,
		"Account": AccountName,
		"Region":  AccountRegion,
		"Project": projectName,
		"Service": serviceName,
	}

	options := &terraform.Options{
		Vars: map[string]any{
			"name_prefix": namePrefix,
			"name_suffix": nameSuffix,

			"vpc": map[string]any{
				"id":   "vpc-013a411b59dd8a08e",
				"tier": "public",
			},

			"microservice": map[string]any{
				"ecs": map[string]any{
					"log": map[string]any{
						"retention_days": 1,
						"prefix":         "ecs",
					},
					"task_definition": map[string]any{},
				},
				"bucket_env": map[string]any{
					"force_destroy": true,
					"versioning":    false,
				},
			},

			"tags": tags,
		},
	}
	return options, nameSuffix
}
