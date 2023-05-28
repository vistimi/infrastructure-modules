package scraper_frontend_test

import (
	"fmt"
	"testing"
	"time"

	"golang.org/x/exp/maps"

	helper_test "github.com/KookaS/infrastructure-modules/modules/services/helper"

	"github.com/gruntwork-io/terratest/modules/terraform"
	terratest_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	backend_dns = "dns_adress_test"
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

	optionsProjectFargate = terraform.WithDefaultRetryableErrors(t, optionsProjectFargate)

	// defer func() {
	// 	if r := recover(); r != nil {
	// 		// destroy all resources if panic
	// 		terraform.Destroy(t, terraformOptions)
	// 	}
	// 	terratest_structure.RunTestStage(t, "cleanup_scraper_frontend", func() {
	// 		terraform.Destroy(t, terraformOptions)
	// 	})
	// }()
	terratest_structure.RunTestStage(t, "deploy_scraper_frontend", func() {
		terraform.InitAndApply(t, optionsProjectFargate)
		bashCode := fmt.Sprintf(`
			gh workflow run %s --repo %s/%s --ref %s \
			-f aws-account-name=%s \
			-f common-name=%s \
			-f task-desired-count=%d \
			-f backend-dns=%s \
			|| exit 1
		`,
			GithubProject.WorkflowFilename,
			GithubProject.Organization,
			GithubProject.Repository,
			GithubProject.Branch,
			helper_test.AccountName,
			commonName,
			helper_test.ServiceTaskDesiredCountFinal,
			backend_dns,
		)
		helper_test.RunGithubWorkflow(t, GithubProject, bashCode)
	})

	helper_test.TestMicroservice(t, optionsProjectFargate, GithubProject)

	dnsUrl := terraform.Output(t, optionsProjectFargate, "alb_dns_name")
	fmt.Printf("\n\nDNS = %s\n\n", terraform.Output(t, optionsProjectFargate, "alb_dns_name"))
	endpoints := []helper_test.EndpointTest{
		{
			Url:                 dnsUrl + GithubProject.HealthCheckPath,
			ExpectedStatus:      200,
			ExpectedBody:        nil,
			MaxRetries:          3,
			SleepBetweenRetries: 20 * time.Second,
		},
	}

	terratest_structure.RunTestStage(t, "validate_rest_endpoints", func() {
		helper_test.TestRestEndpoints(t, endpoints)
	})
}
