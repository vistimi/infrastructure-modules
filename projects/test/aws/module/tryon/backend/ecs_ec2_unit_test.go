package microservice_test

import (
	"fmt"
	"testing"

	"golang.org/x/exp/maps"

	"github.com/aws/aws-sdk-go/aws"
	testAwsProjectModule "github.com/dresspeng/infrastructure-modules/projects/test/aws/module"
	testAwsModule "github.com/dresspeng/infrastructure-modules/test/aws/module"
	"github.com/dresspeng/infrastructure-modules/test/util"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	projectName = "to"
	serviceName = "be"

	Rootpath         = "../../../../../.."
	MicroservicePath = Rootpath + "/module/aws/container/microservice"
)

var (
	AccountName   = util.GetEnvVariable("AWS_PROFILE_NAME")
	AccountId     = util.GetEnvVariable("AWS_ACCOUNT_ID")
	AccountRegion = util.GetEnvVariable("AWS_REGION_NAME")
	DomainName    = fmt.Sprintf("%s.%s", util.GetEnvVariable("DOMAIN_NAME"), util.GetEnvVariable("DOMAIN_SUFFIX"))

	MicroserviceInformation = testAwsModule.MicroserviceInformation{
		Branch:          "trunk", // TODO: make it flexible for testing other branches
		HealthCheckPath: "/ping",
		Docker: testAwsModule.Docker{
			Registry: &testAwsModule.Registry{
				Ecr: &testAwsModule.Ecr{
					Privacy: "private",
				},
			},
			Repository: testAwsModule.Repository{
				Name: "viton-hd-trunk-rest", // TODO: make it flexible for testing other branches
			},
			Image: &testAwsModule.Image{
				Tag: "latest",
			},
		},
	}

	Traffics = []testAwsModule.Traffic{
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(80),
				Protocol: "http",
			},
			Target: testAwsModule.TrafficPoint{
				Port:     util.Ptr(8080),
				Protocol: "http",
			},
			Base: util.Ptr(true),
		},
	}

	Deployment = testAwsModule.DeploymentTest{
		MaxRetries: aws.Int(10),
		Endpoints: []testAwsModule.EndpointTest{
			{
				Command:        util.Ptr(`curl -v -X POST <URL>/prediction -H "Content-Type: application/json; charset=utf-8" -d '{"model_name":"03615_00", "cloth_name":"02783_00"}'`),
				ExpectedStatus: 200,
				MaxRetries:     aws.Int(3),
			},
		},
	}
)

func SetupVars(t *testing.T) (vars map[string]any) {
	return map[string]any{}
}

// https://docs.aws.amazon.com/elastic-inference/latest/developerguide/ei-dlc-ecs-pytorch.html
// https://docs.aws.amazon.com/deep-learning-containers/latest/devguide/deep-learning-containers-ecs-tutorials-training.html
func Test_Unit_Microservice_FPGA_ECS_EC2_VtonHd(t *testing.T) {
	// t.Parallel()
	namePrefix, nameSuffix, tags, traffics, docker, _ := testAwsProjectModule.SetupMicroservice(t, MicroserviceInformation, Traffics)
	vars := SetupVars(t)
	serviceNameSuffix := "unique"

	options := util.Ptr(terraform.Options{
		TerraformDir: MicroservicePath,
		Vars: map[string]interface{}{
			"name": util.Format("-", namePrefix, projectName, serviceName, nameSuffix),

			"vpc": map[string]any{
				"id":   util.GetEnvVariable("VPC_ID"),
				"tier": "public",
			},

			"orchestrator": map[string]any{
				"group": map[string]any{
					"name": serviceNameSuffix,
					"deployment": map[string]any{
						"min_size":     1,
						"max_size":     1,
						"desired_size": 1,

						"containers": []map[string]any{
							{
								"name":                     "unique",
								"docker":                   docker,
								"readonly_root_filesystem": true,
								// "mount_points": []map[string]any{
								// 	{
								// 		"s3": map[string]any{
								// 			"name": "vton-hd",
								// 		},
								// 		"container_path": "/mnt",
								// 		"read_only":      true,
								// 	},
								// },
								// "environments": []map[string]any{
								// 	{
								// 		"name":  "MOUNT",
								// 		"value": "/mnt",
								// 	},
								// },
							},
						},
					},

					"ec2": map[string]any{
						"key_name":       nil,
						"instance_types": []string{"inf1.xlarge"},
						"os":             "linux",
						"os_version":     "2",

						"capacities": []map[string]any{
							{
								"type":   "ON_DEMAND",
								"base":   nil, // no preferred instance amount
								"weight": 50,  // 50% chance
							},
						},
					},
				},
				"ecs": map[string]any{},
			},
			"traffics": traffics,
			"iam": map[string]any{
				"scope":        "accounts",
				"requires_mfa": false,
			},
			// "bucket_env": bucketEnv,

			"tags": tags,
		},
	})
	maps.Copy(options.Vars, vars)

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
		terraform.Init(t, options)
		terraform.Plan(t, options)
		terraform.Apply(t, options)
	})
	terratestStructure.RunTestStage(t, "validate", func() {
		// TODO: test that /etc/ecs/ecs.config is not empty, requires key_name coming from terratest maybe
		name := util.Format("-", namePrefix, projectName, serviceName, nameSuffix)
		serviceName := util.Format("-", name, serviceNameSuffix)
		testAwsModule.ValidateMicroservice(t, name, Deployment, serviceName)
		testAwsModule.ValidateRestEndpoints(t, MicroservicePath, Deployment, Traffics, name, "")
	})
}
