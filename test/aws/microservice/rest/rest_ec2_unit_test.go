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

	Traffic = []testAwsModule.Traffic{
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(80),
				Protocol: "http",
			},
			Target: testAwsModule.TrafficPoint{
				Port:     util.Ptr(80),
				Protocol: "http",
			},
		},
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(81),
				Protocol: "http",
			},
			Target: testAwsModule.TrafficPoint{
				Port:     util.Ptr(80),
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

// https://docs.aws.amazon.com/elastic-inference/latest/developerguide/ei-dlc-ecs-pytorch.html
// https://docs.aws.amazon.com/deep-learning-containers/latest/devguide/deep-learning-containers-ecs-tutorials-training.html
func Test_Unit_Microservice_Rest_EC2_Httpd(t *testing.T) {
	t.Parallel()

	rand.Seed(time.Now().UnixNano())

	// global variables
	id := util.RandomID(4)
	commonName := util.Format("-", projectName, serviceName, util.GetEnvVariable("AWS_PROFILE_NAME"), id)
	commonTags := map[string]string{
		"TestID":  id,
		"Account": AccountName,
		"Region":  AccountRegion,
		"Project": projectName,
		"Service": serviceName,
	}

	instance := testAwsModule.G4dnXlarge
	keySpot := "spot"
	keyOnDemand := "on-demand"

	traffics := []map[string]any{}
	for _, traffic := range Traffic {
		traffics = append(traffics, map[string]any{
			"listener": map[string]any{
				"port":     traffic.Listener.Port,
				"protocol": traffic.Listener.Protocol,
				// "protocol_version": listenerHttpProtocolVersion,
			},
			"target": map[string]any{
				"port":     traffic.Target.Port,
				"protocol": traffic.Target.Protocol,
				// "protocol_version":  targetProtocolVersion,
				"health_check_path": "/",
			},
		})
	}
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
				"traffics": traffics,
				"log": map[string]any{
					"retention_days": 1,
					"prefix":         "ecs",
				},
				"task_definition": map[string]any{
					"gpu":    aws.IntValue(instance.Gpu),
					"cpu":    instance.Cpu,
					"memory": instance.MemoryAllowed,

					"entrypoint": []string{
						"/bin/bash",
						"-c",
					},
					"command": []string{
						"apt update -q; apt install apache2 ufw systemctl curl -yq; ufw app list; systemctl start apache2; curl localhost",
					},
					"readonly_root_filesystem": false,

					"docker": map[string]any{
						"repository": map[string]any{
							"name": "ubuntu",
						},
						"image": map[string]any{
							"tag": "latest",
						},
					},
				},

				"ec2": map[string]map[string]any{
					keySpot: {
						"os":            "linux",
						"os_version":    "2",
						"architecture":  instance.Architecture,
						"instance_type": instance.Name,
						"key_name":      nil,
						"use_spot":      true,
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
							"maximum_scaling_step_size":   1,
							"minimum_scaling_step_size":   1,
						},
					},
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
					"task_desired_count":                 3,
					"task_max_count":                     3,
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
		testAwsModule.ValidateMicroservice(t, commonName, MicroservicePath, Deployment, "")
	})
}
