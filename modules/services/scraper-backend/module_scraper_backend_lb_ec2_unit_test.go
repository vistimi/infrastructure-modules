package scraper_backend_test

// import (
// 	"testing"

// 	"github.com/gruntwork-io/terratest/modules/terraform"
// )

// func Test_Unit_TerraformScraperBackend_LB_EC2(t *testing.T) {
// 	t.Parallel()
// 	terraformOptions := SetupEndpointOptionsScraperBackend(t)
// 	keySpot := "spot"
// 	keyOnDemand := "on-demand"

// 	terraformOptions.Vars["autoscaling_group"] = map[string]map[string]any{
// 		keySpot: {
// 			"min_size":     0,
// 			"desired_size": 1,
// 			"max_size":     2,
// 			"use_spot":     true,
// 		},
// 		keyOnDemand: {
// 			"min_size":     0,
// 			"desired_size": 1,
// 			"max_size":     2,
// 			"use_spot":     false,
// 		},
// 	}
// 	terraformOptions.Vars["capacity_provider"] = map[string]map[string]any{
// 		keySpot: {
// 			"base":           nil, // no preferred instance amount
// 			"weight_percent": 50,  // 50% chance
// 			"scaling": map[string]any{
// 				"target_capacity_cpu_percent": 70,
// 				"maximum_scaling_step_size":   1,
// 				"minimum_scaling_step_size":   1,
// 			},
// 		},
// 		keyOnDemand: {
// 			"base":           nil, // no preferred instance amount
// 			"weight_percent": 50,  // 50% chance
// 			"scaling": map[string]any{
// 				"target_capacity_cpu_percent": 70,
// 				"maximum_scaling_step_size":   1,
// 				"minimum_scaling_step_size":   1,
// 			},
// 		},
// 	}
// 	terraformOptions.Vars["instance"] = map[string]any{
// 		"user_data": nil,
// 		"ec2": map[string]any{
// 			"ami_ssm_architecture": "amazon-linux-2",
// 			"instance_type":        "t2.micro",
// 		},
// 	}
// 	terraformOptions.Vars["deployment"] = map[string]any{
// 		"use_load_balancer": true,
// 		"use_fargate":       false,
// 	}

// 	// options
// 	terraformOptions = terraform.WithDefaultRetryableErrors(t, terraformOptions)

// 	// TestScraperBackend(t, terraformOptions)
// }
