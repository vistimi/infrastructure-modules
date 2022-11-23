package test

import (
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/google/uuid"
	"github.com/gruntwork-io/terratest/modules/terraform"

	test_shell "github.com/gruntwork-io/terratest/modules/shell"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestTerraformScraperBackendUnitTest(t *testing.T) {
	t.Parallel()

	bashCode := `terragrunt init;`
	command := test_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	shellOutput := test_shell.RunCommandAndGetOutput(t, command)
	fmt.Printf("\nStart shell output: %s\n", shellOutput)

	id := uuid.New().String()[0:7]
	account_name := os.Getenv("AWS_PROFILE")
	account_id := os.Getenv("AWS_ID")
	account_region := os.Getenv("AWS_REGION")
	project_name := "scraper"
	service_name := "backend"
	environment_name := fmt.Sprintf("%s-%s", os.Getenv("ENVIRONMENT_NAME"), id)
	common_name := strings.ToLower(fmt.Sprintf("%s-%s-%s-%s-%s", account_name, account_region, project_name, service_name, environment_name))

	listener_port := "80"
	listener_protocol := "HTTP"
	target_port := "8080"
	target_protocol := "HTTP"

	ecs_execution_role_name := "ecs-execution-role-name"
	ecs_task_container_role_name := "ecs-task-container-role-name"

	vpc_id := terraform.Output(t, &terraform.Options{TerraformDir: "../../vpc"}, "vpc_id")

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "",
		Vars: map[string]interface{}{
			"vpc_id":      vpc_id,
			"common_name": common_name,
			"common_tags": map[string]string{
				"Account":     account_name,
				"Region":      account_region,
				"Project":     project_name,
				"Service":     service_name,
				"Environment": environment_name,
			},
			"gh_organization":              "KookaS",
			"gh_repository":                "scraper-backend",
			"listener_port":                listener_port,
			"listener_protocol":            listener_protocol,
			"target_port":                  target_port,
			"target_protocol":              target_protocol,
			"ecs_logs_retention_in_days":   1,
			"user_data":                    nil,
			"protect_from_scale_in":        false,
			"vpc_tier":                     "Public",
			"instance_type_on_demand":      "t2.micro",
			"min_size_on_demand":           "1",
			"max_size_on_demand":           "1",
			"desired_capacity_on_demand":   "1",
			"instance_type_spot":           "t2.micro",
			"min_size_spot":                "1",
			"max_size_spot":                "1",
			"desired_capacity_spot":        "1",
			"ecs_execution_role_name":      ecs_execution_role_name,
			"ecs_task_container_role_name": ecs_task_container_role_name,
		},
	})

	defer func() {
		if r := recover(); r != nil {
			// destroy all resources if panic
			terraform.Destroy(t, terraformOptions)
		}
		test_structure.RunTestStage(t, "cleanup_scraper_backend", func() {
			terraform.Destroy(t, terraformOptions)
		})
	}()

	// test_structure.RunTestStage(t, "deploy_scraper_backend", func() {
	// 	terraform.InitAndApply(t, terraformOptions)
	// })

	// Run Github workflow CI/CD to push iamge on ECR and update ECS
	bashCode = fmt.Sprintf(
		`gh workflow run cicd.yml --repo KookaS/scraper-backend --ref production\
		-f aws-account-name=%s \
		-f aws-account-id=%s \
		-f aws-region=%s \
		-f environment-name="test" \
		-f container-cpu="256" \
		-f container-memory="512" \
		-f container-memory-reservation="500" \
		-f aws-exec-role=%s \
		-f aws-task-role=%s \
		-f keep-images-amount="1"
		echo "Sleep 10 seconds for spawning action"
		sleep 10s
		echo "Continue to check the status"
		# while workflow status == in_progress, wait
		workflowStatus=$(gh run list --workflow CI/CD --limit 1 | awk '{print $1}')
		while [ "${workflowStatus}" != "completed" ]
		do
			echo "Waiting for status workflow to complete: "${workflowStatus}
			sleep 5s
			workflowStatus=$(gh run list --workflow CI/CD --limit 1 | awk '{print $1}')
		done

		echo "Workflow finished: "${workflowStatus}`,
		account_name,
		account_id,
		account_region,
		ecs_execution_role_name,
		ecs_task_container_role_name,
	)
	command = test_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	shellOutput = test_shell.RunCommandAndGetOutput(t, command)
	fmt.Printf("\nWorkflow shell output: %s\n", shellOutput)

	test_structure.RunTestStage(t, "validate_ecr", func() {
		bashCode := fmt.Sprintf(`aws ecr list-images --repository-name %s --region %s --output text --query "imageIds[].[imageTag]"`,
			fmt.Sprintf("%s-repository", common_name),
			account_region,
		)
		command := test_shell.Command{
			Command: "bash",
			Args:    []string{"-c", bashCode},
		}
		actualText := strings.TrimSpace(test_shell.RunCommandAndGetOutput(t, command))
		expectedText := ""

		if !cmp.Equal(expectedText, actualText) {
			t.Errorf("\nexpected:\n%+v,\nactual:\n%+v,\ndiff:%+v",
				expectedText,
				actualText,
				cmp.Diff(expectedText, actualText),
			)
		}
	})
}
