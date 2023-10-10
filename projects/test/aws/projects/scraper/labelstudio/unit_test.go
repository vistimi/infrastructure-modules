package microservice_scraper_backend_test

import (
	"fmt"
	"math/rand"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	testAwsModule "github.com/dresspeng/infrastructure-modules/test/aws/module"
	"github.com/dresspeng/infrastructure-modules/test/util"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	projectName = "sp"
	serviceName = "ls"

	Rootpath         = "../../../../.."
	MicroservicePath = Rootpath + "/modules/aws/projects/scraper/labelstudio"
)

var (
	AccountName   = util.GetEnvVariable("AWS_PROFILE_NAME")
	AccountId     = util.GetEnvVariable("AWS_ACCOUNT_ID")
	AccountRegion = util.GetEnvVariable("AWS_REGION_NAME")
	DomainName    = fmt.Sprintf("%s.%s", util.GetEnvVariable("DOMAIN_NAME"), util.GetEnvVariable("DOMAIN_SUFFIX"))

	Traffic = []testAwsModule.Traffic{
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(8080),
				Protocol: "http",
			},
			Target: testAwsModule.TrafficPoint{
				Port:     util.Ptr(8080),
				Protocol: "http",
			},
		},
	}

	Deployment = testAwsModule.DeploymentTest{
		MaxRetries: aws.Int(5),
		Endpoints: []testAwsModule.EndpointTest{
			{
				Path:           "/",
				ExpectedStatus: 200,
				MaxRetries:     aws.Int(3),
			},
		},
	}
)

func Test_Unit_External_Scraper_LabelStudio(t *testing.T) {
	// t.Parallel()
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

	// instance := testAwsModule.T3Small
	options := &terraform.Options{
		TerraformDir: MicroservicePath,
		Vars: map[string]any{
			"name_prefix": namePrefix,
			"name_suffix": nameSuffix,

			"labelstudio": map[string]any{
				"instance_type":    "t3.small",
				"desired_capacity": 1,
				"max_size":         1,
				"min_size":         1,

				// "postgresql_type":         "rds",
				// "postgresql_machine_type": util.Format(".", "db", instance.Name),
				// "postgresql_password":     "12345678",
				// 	"postgresql_type": "internal",

				// "redis_type":         "elasticache",
				// "redis_machine_type": util.Format(".", "cache", instance.Name),
				// "redis_password":          "12345678",
				// 	"redis_type":      "internal",
			},

			// "create_acm_certificate": true,
			// "route53": map[string]any{
			// 	"zone": map[string]any{
			// 		"name": DomainName,
			// 	},
			// 	"record": map[string]any{
			// 		"subdomain_name": id,
			// 	},
			// },
			"iam": map[string]any{
				"scope":        "accounts",
				"requires_mfa": false,
			},
			"bucket_label": map[string]any{
				"force_destroy": true,
				"versioning":    false,
			},
			"tags": tags,
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
	})
}
