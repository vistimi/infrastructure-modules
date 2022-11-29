package test

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"

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
	common_name := strings.ToLower(fmt.Sprintf("%s-%s-%s", project_name, service_name, environment_name))

	listener_port := 80
	listener_protocol := "HTTP"
	target_port := 8080
	target_protocol := "HTTP"

	ecs_execution_role_name := "ecs-execution-role-name"
	ecs_task_container_role_name := "ecs-task-container-role-name"
	ecs_task_definition_family_name := fmt.Sprintf("%s-family", common_name)
	ecs_task_container_name := fmt.Sprintf("%s-container", common_name)
	bucket_env_name := fmt.Sprintf("%s-env", common_name)
	env_file_name := "production.env"

	// ecr_repository_name := fmt.Sprintf("%s-repository", common_name)

	github_organization := "KookaS"
	github_repository := "scraper-backend"
	github_branch := "production"

	vpc_id := terraform.Output(t, &terraform.Options{TerraformDir: "../../vpc"}, "vpc_id")
	default_security_group_id := terraform.Output(t, &terraform.Options{TerraformDir: "../../vpc"}, "default_security_group_id")
	nat_ids := terraform.OutputList(t, &terraform.Options{TerraformDir: "../../vpc"}, "nat_ids")
	if len(nat_ids) == 0 {
		t.Errorf("No NAT available")
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "",
		Vars: map[string]interface{}{
			"account_region": account_region,
			"account_id":     account_id,
			"account_name":   account_name,
			"vpc_id":         vpc_id,
			"common_name":    common_name,
			"common_tags": map[string]string{
				"Account":     account_name,
				"Region":      account_region,
				"Project":     project_name,
				"Service":     service_name,
				"Environment": environment_name,
			},

			"ecs_execution_role_name":                ecs_execution_role_name,
			"ecs_task_container_role_name":           ecs_task_container_role_name,
			"ecs_logs_retention_in_days":             1,
			"listener_port":                          listener_port,
			"listener_protocol":                      listener_protocol,
			"target_port":                            target_port,
			"target_protocol":                        target_protocol,
			"user_data":                              "echo 'Instance is running!'",
			"protect_from_scale_in":                  false,
			"vpc_tier":                               "Public",
			"instance_type_on_demand":                "t2.micro",
			"min_size_on_demand":                     "1",
			"max_size_on_demand":                     "1",
			"desired_capacity_on_demand":             "1",
			"instance_type_spot":                     "t2.micro",
			"min_size_spot":                          "1",
			"max_size_spot":                          "1",
			"desired_capacity_spot":                  "1",
			"ecs_task_definition_memory":             512,
			"ecs_task_definition_memory_reservation": 500,
			"ecs_task_definition_cpu":                256,
			"ecs_task_definition_family_name":        ecs_task_definition_family_name,
			"ecs_task_container_name":                ecs_task_container_name,
			"bucket_env_name":                        bucket_env_name,
			"env_file_name":                          env_file_name,
			"port_mapping": []map[string]any{
				{
					"hostPort":      8080,
					"protocol":      "tcp",
					"containerPort": 8080,
				},
				{
					"hostPort":      27017,
					"protocol":      "tcp",
					"containerPort": 27017,
				},
			},

			// "repository_name":         ecr_repository_name,
			"repository_image_count":  1,
			"repository_force_delete": true,

			"github_organization": github_organization, // TODO: remove
			"github_repository":   github_repository,

			"vpc_security_group_ids": []string{default_security_group_id},
			"force_destroy":          true,
			"ami_id":                 "ami-09d3b3274b6c5d4aa",
			"instance_type":          "t2.micro",
			"user_data_path":         "mongodb.sh",
			"user_data_args": map[string]string{
				"HOME":            "/home/ec2-user",
				"UID":             "1000",
				"mongodb_version": "6.0.1",
			},
		},
		// to pass AWS credentials
		VarFiles: []string{"terraform_override.tfvars"},
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

	test_structure.RunTestStage(t, "deploy_scraper_backend", func() {
		terraform.InitAndApply(t, terraformOptions)
	})

	ecrInitialImagesAmount := ecrImagesAmount(t, common_name, account_region)
	fmt.Printf("\nInitial amount of images in ECR registry: %d\n", ecrInitialImagesAmount)

	// Run Github workflow CI/CD to push images on ECR and update ECS
	privateInstanceIPMongodb := terraform.Output(t, terraformOptions, "ec2_instance_mongodb_private_ip")
	bashCode = fmt.Sprintf(`
		gh workflow run cicd.yml --repo %s/%s --ref %s\
		-f environment-name=%s \
		-f aws-account-name=%s \
		-f aws-account-id=%s \
		-f aws-region=%s \
		-f task-definition-family-name=%s \
		-f bucket-env-name=%s \
		-f mongodb_adress=%s
		`,
		github_organization,
		github_repository,
		github_branch,
		environment_name,
		account_name,
		account_id,
		account_region,
		ecs_task_definition_family_name,
		bucket_env_name,
		privateInstanceIPMongodb,
	)
	bashCode += fmt.Sprintf(`
	echo "Sleep 10 seconds for spawning action"
	sleep 10s
	echo "Continue to check the status"
	# while workflow status == in_progress, wait
	workflowStatus=$(gh run list --repo %s/%s --branch %s --workflow %s --limit 1 | awk '{print $1}')
	if [$workflowStatus == "could not find any workflows named %s"]; then
		echo $workflowStatus
		exit 0
	fi
	while [ "${workflowStatus}" != "completed" ]
	do
		echo "Waiting for status workflow to complete: "${workflowStatus}
		sleep 5s
		workflowStatus=$(gh run list --repo %s/%s --branch %s --workflow %s --limit 1 | awk '{print $1}')
	done
	echo "Workflow finished: "${workflowStatus}
	`,
		github_organization,
		github_repository,
		github_branch,
		"CI/CD",
		"CI/CD",
		github_organization,
		github_repository,
		github_branch,
		"CI/CD",
	)
	command = test_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	shellOutput = test_shell.RunCommandAndGetOutput(t, command)
	fmt.Printf("\nWorkflow shell output: %s\n", shellOutput)

	test_structure.RunTestStage(t, "validate_ecr", func() {
		ecrCurrentImagesAmount := ecrImagesAmount(t, common_name, account_region)
		assert.Equal(t, ecrInitialImagesAmount, ecrCurrentImagesAmount)
	})

	test_structure.RunTestStage(t, "validate_ecs", func() {
		testEcsTaskVersion(t, ecs_task_definition_family_name, account_region, common_name)
	})
}

func ecrImagesAmount(t *testing.T, common_name, account_region string) int {
	bashCode := fmt.Sprintf(`aws ecr list-images --repository-name %s --region %s --output text --query "imageIds[].[imageTag]" | wc -l`,
		common_name,
		account_region,
	)
	command := test_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	output := strings.TrimSpace(test_shell.RunCommandAndGetOutput(t, command))
	outputInt, err := strconv.Atoi(output)
	if err != nil {
		t.Errorf(fmt.Sprintf("String to int conversion failed: %s", output))
	}
	return outputInt
}

func testEcsTaskVersion(t *testing.T, family_name, account_region, common_name string) {
	bashCode := fmt.Sprintf(`$(aws ecs list-task-definitions \
		--region %s \
		--family-prefix %s \
		--sort DESC \
		--query 'taskDefinitionArns[0]' \
		--output text
	)`,
		account_region,
		family_name,
	)
	command := test_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	latestTaskArn := strings.TrimSpace(test_shell.RunCommandAndGetOutput(t, command))
	fmt.Printf("\nlatestTaskArn = %s\n", latestTaskArn)

	bashCode = fmt.Sprintf(`aws ecs describe-tasks \
		--region %s \
		--cluster %s \
		--query 'tasks[].[taskDefinitionArn]' \
		--output text`,
		account_region,
		fmt.Sprintf("%s-repository", common_name),
	)
	command = test_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	runningTaskArns := strings.Fields(test_shell.RunCommandAndGetOutput(t, command))
	fmt.Printf("\runningTaskArns = %v\n", runningTaskArns)

	for _, runningTaskArn := range runningTaskArns {
		assert.Equal(t, latestTaskArn, runningTaskArn)
	}
}
