package microservice_rest_test

import (
	"fmt"
	"math/rand"
	"testing"
	"time"

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
				Port:     util.Ptr(8080),
				Protocol: "tcp",
			},
			Target: testAwsModule.TrafficPoint{
				Port:     util.Ptr(8081),
				Protocol: "tcp",
			},
		},
	}
)

// https://docs.aws.amazon.com/elastic-inference/latest/developerguide/ei-dlc-ecs-pytorch.html
// https://docs.aws.amazon.com/deep-learning-containers/latest/devguide/deep-learning-containers-ecs-tutorials-training.html
func Test_Unit_Microservice_Grpc_EC2_Httpd(t *testing.T) {
	t.Parallel()

	rand.Seed(time.Now().UnixNano())

	// global variables
	id := util.RandomID(4)
	name := util.Format("-", projectName, serviceName, util.GetEnvVariable("AWS_PROFILE_NAME"), id)
	tags := map[string]string{
		"TestID":  id,
		"Account": AccountName,
		"Region":  AccountRegion,
		"Project": projectName,
		"Service": serviceName,
	}

	instance := testAwsModule.T3Small
	keySpot := "spot"
	keyOnDemand := "on-demand"

	traffics := []map[string]any{}
	for _, traffic := range Traffic {
		traffics = append(traffics, map[string]any{
			"listener": map[string]any{
				"port":             util.Value(traffic.Listener.Port, 8080),
				"protocol":         traffic.Listener.Protocol,
				"protocol_version": "grpc",
			},
			"target": map[string]any{
				"port":             util.Value(traffic.Target.Port, 8081),
				"protocol":         traffic.Target.Protocol,
				"protocol_version": "grpc",
			},
		})
	}
	options := &terraform.Options{
		TerraformDir: MicroservicePath,
		Vars: map[string]any{
			"name": name,
			"tags": tags,

			"vpc": map[string]any{
				"id":   "vpc-013a411b59dd8a08e",
				"tier": "public",
			},

			"ecs": map[string]any{
				"traffics": traffics,
				"task_definition": map[string]any{
					"cpu":                instance.Cpu,
					"memory":             instance.MemoryAllowed,
					"memory_reservation": instance.MemoryAllowed - testAwsModule.ECSReservedMemory,

					"entrypoint": []string{
						"/bin/bash",
						"-c",
					},

					"mount_points": []map[string]any{
						{
							"sourceVolume":  "/var/run/docker.sock",
							"containerPath": "/var/run/docker.sock",
							"readOnly":      false,
						},
					},

					"command": []string{
						fmt.Sprintf("apt-get update -qq; apt install wget docker.io -y -qq; docker --version; wget https://github.com/fullstorydev/grpcurl/releases/download/v1.8.7/grpcurl_1.8.7_linux_%s.tar.gz -q; tar -xf grpcurl_1.8.7_linux_%s.tar.gz; docker run -p 8081:50051 grpc/java-example-hostname", instance.Architecture, instance.Architecture),
					},

					// "health_check": map[string]any{
					// 	"command": []string{"CMD-SHELL", "./grpcurl -plaintext 127.0.0.1:8081 helloworld.Greeter.SayHello || exit 1"},
					// },

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
						"os_version":    "2023",
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
						"os_version":    "2023",
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
					"task_min_count":                     1,
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
		// TODO: test grpc tcp endpoints
	})
}
