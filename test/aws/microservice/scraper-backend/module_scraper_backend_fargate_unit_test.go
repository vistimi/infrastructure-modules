package microservice_scraper_backend_test

import (
	"testing"

	"golang.org/x/exp/maps"

	testAwsModule "github.com/dresspeng/infrastructure-modules/test/aws/module"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func Test_Unit_Microservice_ScraperBackend_Fargate(t *testing.T) {
	// t.Parallel()
	optionsProject, commonName := SetupOptionsRepository(t)

	keySpot := "spot"
	keyOnDemand := "on-demand"
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any), map[string]any{
		"fargate": map[string]any{
			"os":           "linux",
			"architecture": "x86_64",
			"capacity_provider": map[string]map[string]any{
				keySpot: {
					"base":   nil, // no preferred instance amount
					"weight": 50,  // 50% chance
					"key":    "FARGATE",
				},
				keyOnDemand: {
					"base":   nil, // no preferred instance amount
					"weight": 50,  // 50% chance
					"key":    "FARGATE_SPOT",
				},
			},
		},
		"service": map[string]any{
			"deployment_type":                    "fargate",
			"task_min_count":                     0,
			"task_desired_count":                 3,
			"task_max_count":                     3,
			"deployment_minimum_healthy_percent": 66,
		},
	})
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any)["task_definition"].(map[string]any), map[string]any{
		"cpu":    1024,
		"memory": 2048,
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
		testAwsModule.ValidateMicroservice(t, commonName, MicroservicePath, GithubProject, Endpoints)
	})
}
