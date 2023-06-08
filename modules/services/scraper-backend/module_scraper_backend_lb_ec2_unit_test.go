package scraper_backend_test

import (
	"testing"

	"github.com/KookaS/infrastructure-modules/modules/services/microservice"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"golang.org/x/exp/maps"
)

func Test_Unit_TerraformScraperBackend_LB_EC2(t *testing.T) {
	t.Parallel()
	optionsProject, commonName := SetupOptionsProject(t)

	keySpot := "spot"
	keyOnDemand := "on-demand"
	optionsProjectEC2 := &terraform.Options{
		TerraformDir: "",
		Vars: map[string]any{
			"autoscaling_group": map[string]map[string]any{
				keySpot: {
					"min_size":     0,
					"desired_size": 1,
					"max_size":     1,
					"use_spot":     true,
				},
				keyOnDemand: {
					"min_size":     0,
					"desired_size": 1,
					"max_size":     1,
					"use_spot":     false,
				},
			},
			"capacity_provider": map[string]map[string]any{
				keySpot: {
					"base":           nil, // no preferred instance amount
					"weight_percent": 50,  // 50% chance
					"scaling": map[string]any{
						"target_capacity_cpu_percent": 70,
						"maximum_scaling_step_size":   1,
						"minimum_scaling_step_size":   1,
					},
				},
				keyOnDemand: {
					"base":           nil, // no preferred instance amount
					"weight_percent": 50,  // 50% chance
					"scaling": map[string]any{
						"target_capacity_cpu_percent": 70,
						"maximum_scaling_step_size":   1,
						"minimum_scaling_step_size":   1,
					},
				},
			},
			"instance": map[string]any{
				"user_data": nil,
				"ec2": map[string]any{
					"ami_ssm_architecture": "amazon-linux-2023",
					"instance_type":        microservice.T3Small.Name,
					"key_name":             nil,
				},
			},
			"deployment": map[string]any{
				"use_load_balancer": true,
				"use_fargate":       false,
			},
		},
	}
	maps.Copy(optionsProjectEC2.Vars, optionsProject.Vars)
	maps.Copy(optionsProjectEC2.Vars["task_definition"].(map[string]any), map[string]any{
		"cpu":                2048,                                                                // supported CPU values are between 128 CPU units (0.125 vCPUs) and 10240 CPU units (10 vCPUs)
		"memory":             microservice.T3Small.MemoryAllowed - microservice.ECSReservedMemory, // the limit is dependent upon the amount of available memory on the underlying Amazon EC2 instance you use
		"memory_reservation": microservice.T3Small.MemoryAllowed - microservice.ECSReservedMemory, // memory_reservation <= memory
	})

	RunTest(t, optionsProjectEC2, commonName)
}
