package microservice_scraper_backend_test

import (
	"testing"

	"golang.org/x/exp/maps"

	testAwsProjectModule "github.com/dresspeng/infrastructure-modules/projects/test/aws/module"
	testAwsModule "github.com/dresspeng/infrastructure-modules/test/aws/module"
	"github.com/dresspeng/infrastructure-modules/test/util"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func Test_Unit_Microservice_ScraperBackend_ECS_Fargate(t *testing.T) {
	// t.Parallel()
	namePrefix, nameSuffix, tags := testAwsProjectModule.SetupOptionsMicroserviceWrapper(t, projectName, serviceName)
	vars, traffics, docker, bucketEnv := SetupOptionsRepository(t)
	instance := testAwsModule.T3Small

	options := util.Ptr(terraform.Options{
		Vars: map[string]interface{}{
			"name_prefix": namePrefix,
			"name_suffix": nameSuffix,

			"vpc": map[string]any{
				"id":   "vpc-013a411b59dd8a08e",
				"tier": "public",
			},

			"microservice": map[string]any{
				"container": map[string]any{
					"group": map[string]any{

						"deployment": map[string]any{
							"min_size":     1,
							"max_size":     1,
							"desired_size": 1,

							"cpu":    instance.Cpu,                                             // supported CPU values are between 128 CPU units (0.125 vCPUs) and 10240 CPU units (10 vCPUs)
							"memory": instance.MemoryAllowed - testAwsModule.ECSReservedMemory, // the limit is dependent upon the amount of available memory on the underlying Amazon EC2 instance you use

							"container": map[string]any{
								"cpu":                instance.Cpu,                                             // supported CPU values are between 128 CPU units (0.125 vCPUs) and 10240 CPU units (10 vCPUs)
								"memory":             instance.MemoryAllowed - testAwsModule.ECSReservedMemory, // the limit is dependent upon the amount of available memory on the underlying Amazon EC2 instance you use
								"memory_reservation": instance.MemoryAllowed - testAwsModule.ECSReservedMemory, // memory_reservation <= memory

								"docker":                   docker,
								"readonly_root_filesystem": true,
							},
						},

						"fargate": map[string]any{
							// "key_name":       nil,
							// "instance_types": []string{instance.Name},
							// "os":             "linux",
							// "os_version":     "2023",
							// "architecture":   instance.Architecture,
							// "processor":      instance.Processor,

							// "capacities": []map[string]any{{
							// 	"type":   "ON_DEMAND",
							// 	"base":   nil, // no preferred instance amount
							// 	"weight": 50,  // 50% chance
							// },
							// },
						},
					},

					"traffics": traffics,
					"ecs":      map[string]any{},
				},
				"iam": map[string]any{
					"scope":        "accounts",
					"requires_mfa": false,
				},
				"bucket_env": bucketEnv,
			},

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
		terraform.InitAndApply(t, options)
	})
	terratestStructure.RunTestStage(t, "validate", func() {
		// TODO: test that /etc/ecs/ecs.config is not empty, requires key_name coming from terratest maybe
		name := util.Format("-", namePrefix, projectName, serviceName, nameSuffix)
		testAwsModule.ValidateMicroservice(t, name, Deployment)
		testAwsModule.ValidateRestEndpoints(t, MicroservicePath, Deployment, Traffic, name, "")
	})
}
