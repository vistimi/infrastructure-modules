package test

import (
	"testing"
	"os"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// An example of how to test the simple Terraform module in examples/terraform-basic-example using Terratest.
func TestTerraformMongodbUpAndRunning(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../",

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"region": "us-east-1",
			"subnet_id": "subnet-0000000000000",
			"vpc_security_group_ids": []string{"00000"},
			"common_tags": map[string]string{"testTag": "testTasgValue"},
			"ami_id": "ami-09d3b3274b6c5d4aa",
			"instance_type": "t2.micro",
			"user_data_path": "../user-data.sh",
			"user_data_args": map[string]string{
				  "bucket_name_mount_helper" : "global-mount-helper",
				  "bucket_name_mongodb"      : "scraper_test-env_test-mongodb",
				  "bucket_name_pictures"     : "scraper_test-env_test-pictures",
				  "mongodb_version"          : "6.0.1",
				  "aws_region"               : os.Getenv("AWS_REGION"),
				  "aws_profile"              : os.Getenv("AWS_PROFILE"),
				  "aws_access_key"           : os.Getenv("AWS_ACCESS_KEY"),
				  "aws_secret_key"           : os.Getenv("AWS_SECRET_KEY"),
				},
		},

		// Disable colors in Terraform commands so its easier to parse stdout/stderr
		NoColor: true,
	})

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer terraform.Destroy(t, terraformOptions)

	// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
	terraform.InitAndApply(t, terraformOptions)

	// Run `terraform output` to get the values of output variables
	actualTextExample := terraform.Output(t, terraformOptions, "example")
	actualTextExample2 := terraform.Output(t, terraformOptions, "example2")
	actualExampleList := terraform.OutputList(t, terraformOptions, "example_list")
	actualExampleMap := terraform.OutputMap(t, terraformOptions, "example_map")

	// Verify we're getting back the outputs we expect
	assert.Equal(t, expectedText, actualTextExample)
	assert.Equal(t, expectedText, actualTextExample2)
	assert.Equal(t, expectedList, actualExampleList)
	assert.Equal(t, expectedMap, actualExampleMap)
}