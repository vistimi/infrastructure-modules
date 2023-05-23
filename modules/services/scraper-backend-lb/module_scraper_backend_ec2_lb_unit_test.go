package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func Test_Unit_TerraformScraperBackend_EC2_LB(t *testing.T) {
	t.Parallel()
	terraformOptions := SetupHttpOptions(t)
	terraformOptions.Vars["use_fargate"] = false

	// options
	terraformOptions = terraform.WithDefaultRetryableErrors(t, terraformOptions)

	// defer func() {
	// 	if r := recover(); r != nil {
	// 		// destroy all resources if panic
	// 		terraform.Destroy(t, terraformOptions)
	// 	}
	// 	test_structure.RunTestStage(t, "cleanup_scraper_backend", func() {
	// 		terraform.Destroy(t, terraformOptions)
	// 	})
	// }()

	TestScraperBackend(t, terraformOptions)
}
