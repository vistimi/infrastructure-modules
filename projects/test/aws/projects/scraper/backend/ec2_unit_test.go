package microservice_scraper_backend_test

import (
	"testing"

	"golang.org/x/exp/maps"

	testAwsModule "github.com/dresspeng/infrastructure-modules/test/aws/module"
	"github.com/dresspeng/infrastructure-modules/test/util"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func Test_Unit_Microservice_ScraperBackend_EC2(t *testing.T) {
	// t.Parallel()
	optionsProject, namePrefix, nameSuffix := SetupOptionsRepository(t)

	maxTaskCount := 3

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
			"task_desired_count":                 maxTaskCount,
			"task_max_count":                     maxTaskCount,
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
		name := util.Format("-", namePrefix, projectName, serviceName, nameSuffix)
		testAwsModule.ValidateMicroservice(t, name, MicroservicePath, Deployment, Traffic, "microservice")
	})
}
