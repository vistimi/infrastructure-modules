package microservice_cuda_test

import (
	"fmt"
	"testing"

	"golang.org/x/exp/maps"

	testAwsModule "github.com/dresspeng/infrastructure-modules/test/aws/module"
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
	GithubProject = testAwsModule.GithubProjectInformation{
		Organization: "dresspeng",
		Repository:   "scraper-detector",
		Branch:       "trunk", // TODO: make it flexible for testing other branches
		ImageTag:     "latest",
	}

	Endpoints = []testAwsModule.EndpointTest{}
)

func Test_Unit_Microservice_Cuda_EC2(t *testing.T) {
	t.Parallel()
	optionsProject, commonName := SetupOptionsRepository(t)

	instance := testAwsModule.T3Small
	keySpot := "spot"
	keyOnDemand := "on-demand"
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any), map[string]any{
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
			"task_min_count":                     0,
			"task_desired_count":                 3,
			"task_max_count":                     3,
			"deployment_minimum_healthy_percent": 66, // % tasks running required
			"deployment_circuit_breaker": map[string]any{
				"enable":   true,  // service deployment fail if no steady state
				"rollback": false, // rollback in case of failure
			},
		},
	})
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any)["task_definition"].(map[string]any), map[string]any{
		"cpu":    instance.Cpu,
		"memory": instance.MemoryAllowed - testAwsModule.ECSReservedMemory,
		"command": []string{
			"sh",
			"-c",
			"nvidia-smi",
		},
	})

	defer func() {
		if r := recover(); r != nil {
			// destroy all resources if panic
			terraform.Destroy(t, optionsProject)
		}
		terratestStructure.RunTestStage(t, "cleanup", func() {
			terraform.Destroy(t, optionsProject)
		})
	}()

	terratestStructure.RunTestStage(t, "deploy", func() {
		terraform.InitAndApply(t, optionsProject)
	})
	terratestStructure.RunTestStage(t, "validate", func() {
		// TODO: test that /etc/ecs/ecs.config is not empty, requires key_name coming from terratest maybe
		testAwsModule.ValidateMicroservice(t, commonName, MicroservicePath, GithubProject, Endpoints)
	})
}

func SetupOptionsRepository(t *testing.T) (*terraform.Options, string) {
	optionsMicroservice, commonName := testAwsModule.SetupOptionsMicroservice(t, projectName, serviceName)

	optionsProject := &terraform.Options{
		TerraformDir: MicroservicePath,
		Vars:         map[string]any{},
	}

	maps.Copy(optionsProject.Vars, optionsMicroservice.Vars)
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any), map[string]any{
		"vpc": map[string]any{
			"name":      commonName,
			"cidr_ipv4": "102.0.0.0/16",
			"tier":      "public",
		},
		"iam": map[string]any{
			"scope":        "microservices",
			"requires_mfa": false,
		},
	})
	envKey := fmt.Sprintf("%s.env", GithubProject.Branch)
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any)["task_definition"].(map[string]any), map[string]any{
		"env_file_name": envKey,
		"docker": map[string]any{
			"registry": map[string]any{
				"name": "nvidia",
			},
			"repository": map[string]any{
				"name": "cuda",
			},
			"image": map[string]any{
				"tag": "12.2.0-runtime-ubuntu22.04",
			},
		},
	})
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["bucket_env"].(map[string]any), map[string]any{
		"file_key":  envKey,
		"file_path": "override.env",
	})

	return optionsProject, commonName
}
