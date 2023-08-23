package microservice_rest_test

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
	projectName = "ms"
	serviceName = "grpc"

	Rootpath         = "../../../.."
	MicroservicePath = Rootpath + "/module/aws/container/microservice"
)

var (
	AccountName   = util.GetEnvVariable("AWS_PROFILE_NAME")
	AccountId     = util.GetEnvVariable("AWS_ACCOUNT_ID")
	AccountRegion = util.GetEnvVariable("AWS_REGION_NAME")
	DomainName    = fmt.Sprintf("%s.%s", util.GetEnvVariable("DOMAIN_NAME"), util.GetEnvVariable("DOMAIN_SUFFIX"))

	HealthCheckPath = "/helloworld.Greeter/SayHello"
	statusCode      = "0"

	// gRPC requires HTTPS
	Traffic = []testAwsModule.Traffic{
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(443),
				Protocol: "https",
			},
			Target: testAwsModule.TrafficPoint{
				Port:     util.Ptr(50051),
				Protocol: "http",
			},
		},
	}

	Deployment = testAwsModule.DeploymentTest{
		MaxRetries: aws.Int(10),
		Endpoints: []testAwsModule.EndpointTest{
			{
				Request:    util.Ptr(`{"name": "World"}`),
				Path:       HealthCheckPath,
				MaxRetries: util.Ptr(3),
			},
		},
	}
)

// https://docs.aws.amazon.com/elastic-inference/latest/developerguide/ei-dlc-ecs-pytorch.html
// https://docs.aws.amazon.com/deep-learning-containers/latest/devguide/deep-learning-containers-ecs-tutorials-training.html
func Test_Unit_Microservice_Grpc_EC2(t *testing.T) {
	t.Parallel()

	rand.Seed(time.Now().UnixNano())

	// global variables
	id := "fghj" // util.RandomID(4)
	name := util.Format("-", projectName, serviceName, util.GetEnvVariable("AWS_PROFILE_NAME"), id)
	tags := map[string]string{
		"TestID":  id,
		"Account": AccountName,
		"Region":  AccountRegion,
		"Project": projectName,
		"Service": serviceName,
	}

	instance := testAwsModule.T3Small
	// keySpot := "spot"
	keyOnDemand := "on-demand"

	traffics := []map[string]any{}
	for _, traffic := range Traffic {
		traffics = append(traffics, map[string]any{
			"listener": map[string]any{
				"port":     util.Value(traffic.Listener.Port, 443),
				"protocol": traffic.Listener.Protocol,
			},
			"target": map[string]any{
				"port":              util.Value(traffic.Target.Port, 443),
				"protocol":          traffic.Target.Protocol,
				"protocol_version":  "grpc",
				"health_check_path": HealthCheckPath,
				"status_code":       statusCode,
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
					// container
					"cpu":                instance.Cpu,
					"memory":             instance.MemoryAllowed,
					"memory_reservation": instance.MemoryAllowed - testAwsModule.ECSReservedMemory,

					"readonly_root_filesystem": false,

					"docker": map[string]any{
						"registry": map[string]any{
							"name": "grpc",
						},
						"repository": map[string]any{
							"name": "java-example-hostname",
						},
						"image": map[string]any{
							"tag": "latest",
						},
					},
				},

				"ec2": map[string]map[string]any{
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

			"route53": map[string]any{
				"zones": []map[string]any{
					{
						"name": fmt.Sprintf("%s.%s", util.GetEnvVariable("DOMAIN_NAME"), util.GetEnvVariable("DOMAIN_SUFFIX")),
					},
				},
				"record": map[string]any{
					"prefixes":       []string{"www"},
					"subdomain_name": name,
				},
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
		testAwsModule.ValidateMicroservice(t, name, Deployment)
		// testAwsModule.ValidateGrpcEndpoints(t, MicroservicePath, Deployment, Traffic, name, "")
	})
}
