package scraper_backend_test

import (
	"fmt"
	"testing"
	"time"

	"golang.org/x/exp/maps"

	helper_test "github.com/KookaS/infrastructure-modules/modules/services/helper"

	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

// TODO: autoscaling
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy#ecs-service-autoscaling
// https://towardsaws.com/aws-ecs-service-autoscaling-terraform-included-d4b46997742b

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

	optionsProjectFargate = terraform.WithDefaultRetryableErrors(t, optionsProjectFargate)

	// defer func() {
	// 	if r := recover(); r != nil {
	// 		// destroy all resources if panic
	// 		terraform.Destroy(t, terraformOptions)
	// 	}
	// 	test_structure.RunTestStage(t, "cleanup_scraper_backend", func() {
	// 		terraform.Destroy(t, terraformOptions)
	// 	})
	// }()
	test_structure.RunTestStage(t, "deploy_scraper_backend", func() {
		terraform.InitAndApply(t, optionsProjectFargate)
		bashCode := fmt.Sprintf(`
			gh workflow run %s --repo %s/%s --ref %s \
			-f aws-account-id=%s \
			-f aws-account-name=%s \
			-f aws-region=%s \
			-f common-name=%s \
			-f task-desired-count=%d \
			|| exit 1
		`,
			GithubProject.WorkflowFilename,
			GithubProject.Organization,
			GithubProject.Repository,
			GithubProject.Branch,
			helper_test.AccountId,
			helper_test.AccountName,
			helper_test.AccountRegion,
			commonName,
			helper_test.ServiceTaskDesiredCountFinal,
		)
		helper_test.RunGithubWorkflow(t, GithubProject, bashCode)
	})

	helper_test.TestMicroservice(t, optionsProjectFargate, GithubProject)

	dnsUrl := terraform.Output(t, optionsProjectFargate, "alb_dns_name")
	endpoints := []helper_test.EndpointTest{
		{
			Url:                 dnsUrl + GithubProject.HealthCheckPath,
			ExpectedStatus:      200,
			ExpectedBody:        `"ok"`,
			MaxRetries:          3,
			SleepBetweenRetries: 20 * time.Second,
		},
		{
			Url:                 dnsUrl + "/tags/wanted",
			ExpectedStatus:      200,
			ExpectedBody:        `[]`,
			MaxRetries:          3,
			SleepBetweenRetries: 20 * time.Second,
		},
	}

	test_structure.RunTestStage(t, "validate_rest_endpoints", func() {
		helper_test.TestRestEndpoints(t, endpoints)
	})

	fmt.Printf("\n\nDNS: %s\n\n", terraform.Output(t, optionsProjectFargate, "alb_dns_name"))
}
