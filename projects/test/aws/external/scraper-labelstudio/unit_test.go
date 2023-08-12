package microservice_scraper_backend_test

import (
	"fmt"
	"math/rand"
	"os"
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
	projectName = "scraper"
	serviceName = "ls"

	Rootpath         = "../../../.."
	MicroservicePath = Rootpath + "/module/aws/projects/scraper/labelstudio"
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

	instance := testAwsModule.T3Small
	options := &terraform.Options{
		TerraformDir: MicroservicePath,
		Vars: map[string]any{
			"name_prefix": namePrefix,
			"name_suffix": nameSuffix,
			"labelstudio": map[string]any{
				"instance_type":    instance.Name,
				"desired_capacity": 2,
				"max_size":         3,
				"min_size":         1,
				// "create_acm_certificate": true,
				"label_studio_additional_set": map[string]any{
					"global.image.repository": "heartexlabs/label-studio",
					"global.image.tag":        "develop",
				},
				"postgresql_type":         "rds",
				"postgresql_machine_type": "db.t2.micro",
				"redis_type":              "elasticache",
				"redis_machine_type":      "cache.t3.micro",
			},
			// "route53": map[string]any{
			// 	"zone": map[string]any{
			// 		"name": DomainName,
			// 	},
			// 	"record": map[string]any{
			// 		"subdomain_name": id,
			// 	},
			// },
			"vpc": map[string]any{
				"id": "vpc-0d5c1d5379f616e2f",
			},
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

	// defer func() {
	// 	if r := recover(); r != nil {
	// 		// destroy all resources if panic
	// 		terraform.Destroy(t, options)
	// 	}
	// 	terratestStructure.RunTestStage(t, "cleanup", func() {
	// 		terraform.Destroy(t, options)
	// 	})
	// }()

	terratestStructure.RunTestStage(t, "deploy", func() {
		terraform.InitAndApply(t, options)
	})
	terratestStructure.RunTestStage(t, "validate", func() {
		// TODO: test that /etc/ecs/ecs.config is not empty, requires key_name coming from terratest maybe
		name := util.Format("-", util.Format("-", projectName, serviceName), nameSuffix)
		os.Setenv(terratestStructure.SKIP_STAGE_ENV_VAR_PREFIX+"validate_microservice", "true")
		testAwsModule.ValidateMicroservice(t, name, MicroservicePath, Deployment, Traffic, "microservice")

	})
}
