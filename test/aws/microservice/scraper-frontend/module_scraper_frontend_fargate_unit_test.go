package microservice_scraper_frontend_test

import (
	"testing"

	"golang.org/x/exp/maps"

	"github.com/KookaS/infrastructure-modules/test"
	testAwsModule "github.com/KookaS/infrastructure-modules/test/aws/module"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func Test_Unit_Microservice_ScraperFrontend_Fargate(t *testing.T) {
	t.Parallel()
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

	test.RunTest(t, optionsProject)
	terratestStructure.RunTestStage(t, "validate", func() {
		testAwsModule.ValidateMicroservice(t, commonName, MicroservicePath, GithubProject, Endpoints)
	})
}
