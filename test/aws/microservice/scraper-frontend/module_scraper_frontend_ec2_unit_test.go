package microservice_scraper_frontend_test

import (
	"fmt"
	"testing"

	"golang.org/x/exp/maps"

	testAwsModule "github.com/KookaS/infrastructure-modules/test/aws/module"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func Test_Unit_Microservice_ScraperFrontend_EC2(t *testing.T) {
	t.Parallel()
	optionsProject, commonName := SetupOptionsRepository(t)

	// https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html#enable_task_iam_roles
	// ECS_ENABLE_TASK_IAM_ROLE=true // Uses IAM roles for tasks for containers with the bridge and default network modes
	// ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true // Uses IAM roles for tasks for containers with the host network mode

	userDataOnDemand := fmt.Sprintf(`#!/bin/bash\ncat <<'EOF' >> /etc/ecs/ecs.config\nECS_CLUSTER=%s\nECS_LOGLEVEL=debug\n%s\nECS_RESERVED_MEMORY=%d\nEOF`, commonName, "ECS_ENABLE_TASK_IAM_ROLE=true", testAwsModule.ECSReservedMemory)

	userDataSpot := fmt.Sprintf(`#!/bin/bash\ncat <<'EOF' >> /etc/ecs/ecs.config\nECS_CLUSTER=%s\nECS_LOGLEVEL=debug\n%s\nECS_RESERVED_MEMORY=%d\nECS_ENABLE_SPOT_INSTANCE_DRAINING=true\nEOF`, commonName, "ECS_ENABLE_TASK_IAM_ROLE=true", testAwsModule.ECSReservedMemory)

	instance := testAwsModule.T3Small
	keySpot := "spot"
	keyOnDemand := "on-demand"
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any), map[string]any{
		"ec2": map[string]map[string]any{
			keySpot: {
				"user_data":     userDataSpot,
				"os":            "linux",
				"os_version":    "2023",
				"architecture":  "x64",
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
				"user_data":     userDataOnDemand,
				"os":            "linux",
				"os_version":    "2023",
				"architecture":  "x64",
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
		"cpu":                instance.Cpu,                                             // supported CPU values are between 128 CPU units (0.125 vCPUs) and 10240 CPU units (10 vCPUs)
		"memory":             instance.MemoryAllowed - testAwsModule.ECSReservedMemory, // the limit is dependent upon the amount of available memory on the underlying Amazon EC2 instance you use
		"memory_reservation": instance.MemoryAllowed - testAwsModule.ECSReservedMemory, // memory_reservation <= memory
	})

	// defer func() {
	// 	if r := recover(); r != nil {
	// 		// destroy all resources if panic
	// 		terraform.Destroy(t, optionsProject)
	// 	}
	// 	terratestStructure.RunTestStage(t, "cleanup", func() {
	// 		terraform.Destroy(t, optionsProject)
	// 	})
	// }()

	terratestStructure.RunTestStage(t, "deploy", func() {
		terraform.InitAndApply(t, optionsProject)
	})
	terratestStructure.RunTestStage(t, "validate", func() {
		testAwsModule.ValidateMicroservice(t, commonName, MicroservicePath, GithubProject, Endpoints)
	})
}
