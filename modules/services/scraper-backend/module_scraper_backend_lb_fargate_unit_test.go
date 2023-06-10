package scraper_backend_test

import (
	"testing"

	"github.com/KookaS/infrastructure-modules/modules/components/microservice"
	"golang.org/x/exp/maps"
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
	maps.Copy(optionsProject.Vars["ecs"].(map[string]any), map[string]any{
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
		"fargate": map[string]any{
			"os":           "LINUX",
			"architecture": "X86_64",
		},
		"service": map[string]any{
			"use_load_balancer":                  true,
			"use_fargate":                        true,
			"task_desired_count":                 microservice.ServiceTaskDesiredCountInit,
			"deployment_minimum_healthy_percent": 100,
		},
	})
	maps.Copy(optionsProject.Vars["ecs"].(map[string]any)["task_definition"].(map[string]any), map[string]any{
		"cpu":    512,
		"memory": 1024,
		// "memory_reservation": 1024,
	})

	RunTestLB(t, optionsProject, commonName)
}
