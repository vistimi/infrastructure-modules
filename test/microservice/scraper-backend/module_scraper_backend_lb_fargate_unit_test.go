package scraper_backend_test

import (
	"testing"

	"github.com/KookaS/infrastructure-modules/test/microservice"
	"golang.org/x/exp/maps"
)

// TODO: autoscaling
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy#ecs-service-autoscaling
// https://towardsaws.com/aws-ecs-service-autoscaling-terraform-included-d4b46997742b
// iam application-autoscaling

// FIXME: no fargate spot, only on-demand is working
func Test_Unit_ScraperBackend_LB_Fargate(t *testing.T) {
	t.Parallel()
	optionsProject, commonName := SetupOptionsProject(t)

	keySpot := "spot"
	keyOnDemand := "on-demand"
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any), map[string]any{
		"fargate": map[string]any{
			"os":           "LINUX",
			"architecture": "X86_64",
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
		},
		"service": map[string]any{
			"use_fargate":                        true,
			"task_desired_count":                 microservice.ServiceTaskDesiredCount,
			"deployment_minimum_healthy_percent": 66,
		},
	})
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any)["task_definition"].(map[string]any), map[string]any{
		"cpu":    512,
		"memory": 1024,
	})

	RunTest(t, optionsProject, commonName)
}
