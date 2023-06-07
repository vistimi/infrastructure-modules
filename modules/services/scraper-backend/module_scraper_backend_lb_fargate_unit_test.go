package scraper_backend_test

import (
	"testing"

	"golang.org/x/exp/maps"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// TODO: autoscaling
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy#ecs-service-autoscaling
// https://towardsaws.com/aws-ecs-service-autoscaling-terraform-included-d4b46997742b
// iam application-autoscaling

// FIXME: no fargate spot, only on-demand is working
func Test_Unit_TerraformScraperBackend_LB_Fargate(t *testing.T) {
	t.Parallel()
	optionsProject, commonName := SetupOptionsProject(t)

	keySpot := "spot"
	keyOnDemand := "on-demand"
	optionsProjectFargate := &terraform.Options{
		TerraformDir: "",
		Vars: map[string]any{
			"capacity_provider": map[string]map[string]any{
				keySpot: {
					"base":           nil, // no preferred instance amount
					"weight_percent": 50,  // 50% chance
					"fargate":        "FARGATE",
				},
				keyOnDemand: {
					"base":           nil, // no preferred instance amount
					"weight_percent": 50,  // 50% chance
					"fargate":        "FARGATE_SPOT",
				},
			},
			"instance": map[string]any{
				"user_data": nil,
				"fargate": map[string]any{
					"os":           "LINUX",
					"architecture": "X86_64",
				},
			},
			"deployment": map[string]any{
				"use_load_balancer": true,
				"use_fargate":       true,
			},
		},
	}
	maps.Copy(optionsProjectFargate.Vars, optionsProject.Vars)
	maps.Copy(optionsProjectFargate.Vars["task_definition"].(map[string]any), map[string]any{
		"cpu":    512,
		"memory": 1024,
		// "memory_reservation": 1024,
	})

	RunTest(t, optionsProjectFargate, commonName)
}
