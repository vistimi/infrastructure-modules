package microservice_cuda_test

import (
	"fmt"
	"math/rand"
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
	serviceName = "detector"

	Rootpath         = "../../../.."
	MicroservicePath = Rootpath + "/module/aws/container/microservice"
)

var (
	AccountName   = util.GetEnvVariable("AWS_PROFILE_NAME")
	AccountId     = util.GetEnvVariable("AWS_ACCOUNT_ID")
	AccountRegion = util.GetEnvVariable("AWS_REGION_NAME")
	DomainName    = fmt.Sprintf("%s.%s", util.GetEnvVariable("DOMAIN_NAME"), util.GetEnvVariable("DOMAIN_SUFFIX"))

	GithubProject = testAwsModule.GithubProjectInformation{
		Organization: "dresspeng",
		Repository:   "scraper-detector",
		Branch:       "trunk", // TODO: make it flexible for testing other branches
		ImageTag:     "latest",
	}

	Endpoints = []testAwsModule.EndpointTest{}
)

// https://docs.aws.amazon.com/elastic-inference/latest/developerguide/ei-dlc-ecs-pytorch.html
func Test_Unit_Microservice_Cuda_EC2_Pytorch(t *testing.T) {
	t.Parallel()

	rand.Seed(time.Now().UnixNano())

	// global variables
	id := util.RandomID(4)
	commonName := util.Format(projectName, serviceName, util.GetEnvVariable("AWS_PROFILE_NAME"), id)
	commonTags := map[string]string{
		"TestID":  id,
		"Account": AccountName,
		"Region":  AccountRegion,
		"Project": projectName,
		"Service": serviceName,
	}

	instance := testAwsModule.G4dnXlarge
	// keySpot := "spot"
	keyOnDemand := "on-demand"

	options := &terraform.Options{
		TerraformDir: MicroservicePath,
		Vars: map[string]any{
			"name": commonName,
			"tags": commonTags,

			"vpc": map[string]any{
				"id":   "vpc-0d5c1d5379f616e2f",
				"tier": "public",
			},

			"ecs": map[string]any{
				"traffics": []map[string]any{
					{
						"listener": map[string]any{
							"port":     80,
							"protocol": "tcp",
						},
						"target": map[string]any{
							"port":     8080,
							"protocol": "tcp",
						},
						"base": true,
					},
					{
						"listener": map[string]any{
							"port":     8081,
							"protocol": "tcp",
						},
						"target": map[string]any{
							"port":     8081,
							"protocol": "tcp",
						},
					},
				},
				"log": map[string]any{
					"retention_days": 1,
					"prefix":         "ecs",
				},
				"task_definition": map[string]any{
					"gpu":    aws.IntValue(instance.Gpu),
					"cpu":    instance.Cpu,
					"memory": instance.MemoryAllowed,
					// "command": []string{
					// 	"sh",
					// 	"-c",
					// 	"nvidia-smi",
					// },
					"entry_point": []string{
						"/bin/bash",
						"-c",
						"mxnet-model-server --start --foreground --mms-config /home/model-server/config.properties --models densenet-eia=https://aws-dlc-sample-models.s3.amazonaws.com/pytorch/densenet_eia/densenet_eia.mar",
					},
					"health_check": map[string]any{
						"retries": 2,
						"command": []string{
							"CMD-SHELL",
							"LD_LIBRARY_PATH=/opt/ei_health_check/lib /opt/ei_health_check/bin/health_check",
						},
						"timeout":     5,
						"interval":    30,
						"startPeriod": 60,
					},
					"docker": map[string]any{
						"registry": map[string]any{
							"name": "pytorch",
						},
						"repository": map[string]any{
							"name": "pytorch",
						},
						"image": map[string]any{
							"tag": "2.0.1-cuda11.7-cudnn8-runtime",
						},
					},
				},

				"ec2": map[string]map[string]any{
					// keySpot: {
					// 	"os":            "linux",
					// 	"os_version":    "2",
					// 	"architecture":  instance.Architecture,
					// 	"instance_type": instance.Name,
					// 	"key_name":      nil,
					// 	"use_spot":      true,
					// 	"asg": map[string]any{
					// 		"instance_refresh": map[string]any{
					// 			"strategy": "Rolling",
					// 			"preferences": map[string]any{
					// 				"checkpoint_delay":       600,
					// 				"checkpoint_percentages": []int{35, 70, 100},
					// 				"instance_warmup":        300,
					// 				"min_healthy_percentage": 80,
					// 			},
					// 			"triggers": []string{"tag"},
					// 		},
					// 	},
					// 	"capacity_provider": map[string]any{
					// 		"base":                        nil, // no preferred instance amount
					// 		"weight":                      50,  // 50% chance
					// 		"target_capacity_cpu_percent": 70,
					// 		"maximum_scaling_step_size":   1,
					// 		"minimum_scaling_step_size":   1,
					// 	},
					// },
					keyOnDemand: {
						"os":            "linux",
						"os_version":    "2",
						"architecture":  instance.Architecture,
						"instance_type": instance.Name,
						"key_name":      nil,
						"use_spot":      false,
						"asg": map[string]any{
							"instance_refresh": map[string]any{
								"strategy": "Rolling",
								"preferences": map[string]any{
									"checkpoint_delay":       600,
									"checkpoint_percentages": []int{35, 70, 100},
									"instance_warmup":        300,
									"min_healthy_percentage": 80,
								},
								"triggers": []string{"tag"},
							},
						},
						"capacity_provider": map[string]any{
							"base":                        nil, // no preferred instance amount
							"weight":                      50,  // 50% chance
							"target_capacity_cpu_percent": 70,
							// "maximum_scaling_step_size":   1,
							// "minimum_scaling_step_size":   1,
						},
					},
				},

				"service": map[string]any{
					"deployment_type":                    "ec2",
					"task_min_count":                     0,
					"task_desired_count":                 1,
					"task_max_count":                     1,
					"deployment_minimum_healthy_percent": 66, // % tasks running required
					"deployment_circuit_breaker": map[string]any{
						"enable":   true,  // service deployment fail if no steady state
						"rollback": false, // rollback in case of failure
					},
				},
			},

			"iam": map[string]any{
				"scope":        "accounts",
				"requires_mfa": false,
			},
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
		testAwsModule.ValidateMicroservice(t, commonName, MicroservicePath, GithubProject, Endpoints)
	})
}
