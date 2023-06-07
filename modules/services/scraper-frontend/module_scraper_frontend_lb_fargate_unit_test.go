package scraper_frontend_test

import (
	"testing"

	"golang.org/x/exp/maps"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func Test_Unit_TerraformScraperfrontend_LB_Fargate(t *testing.T) {
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

	RunTest(t, optionsProjectFargate, commonName)
}
