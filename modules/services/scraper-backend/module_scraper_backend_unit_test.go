package test

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"testing"

	awsSDK "github.com/aws/aws-sdk-go/aws"
	"github.com/google/uuid"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"

	test_shell "github.com/gruntwork-io/terratest/modules/shell"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestTerraformScraperBackendUnitTest(t *testing.T) {
	t.Parallel()

	// init
	bashCode := `terragrunt init;`
	command := test_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	shellOutput := test_shell.RunCommandAndGetOutput(t, command)
	fmt.Printf("\nStart shell output: %s\n", shellOutput)

	// vpc variables
	vpc_id := terraform.Output(t, &terraform.Options{TerraformDir: "../../vpc"}, "vpc_id")
	default_security_group_id := terraform.Output(t, &terraform.Options{TerraformDir: "../../vpc"}, "default_security_group_id")
	nat_ids := terraform.OutputList(t, &terraform.Options{TerraformDir: "../../vpc"}, "nat_ids")
	if len(nat_ids) == 0 {
		t.Errorf("No NAT available")
	}

	// global variables
	id := uuid.New().String()[0:7]
	account_name := os.Getenv("AWS_PROFILE")
	account_id := os.Getenv("AWS_ID")
	account_region := os.Getenv("AWS_REGION")
	project_name := "scraper"
	service_name := "backend"
	environment_name := fmt.Sprintf("%s-%s", os.Getenv("ENVIRONMENT_NAME"), id)
	common_name := strings.ToLower(fmt.Sprintf("%s-%s-%s", project_name, service_name, environment_name))

	// end
	listener_port := 80
	listener_protocol := "HTTP"
	target_port := 8080
	target_protocol := "HTTP"

	ecs_execution_role_name := "ecs-execution-role-name"
	ecs_task_container_role_name := "ecs-task-container-role-name"
	env_file_name := "production.env"
	cpu := 256
	memory := 512
	memory_reservation := 500

	github_workflow_file_name_ecr := "ecr.yml"
	github_workflow_name_ecr := "ECR"
	github_workflow_file_name_env := "s3-env.yml"
	github_workflow_name_env := "S3-env"
	github_workflow_file_name_ecs := "ecs.yml"
	github_workflow_name_ecs := "ECS"
	github_organization := "KookaS"
	github_repository := "scraper-backend"
	github_branch := "production"

	// options
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
			"ecs_task_definition_memory":             memory,
			"ecs_task_definition_memory_reservation": memory_reservation,
			"ecs_task_definition_cpu":                cpu,
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

			"github_workflow_file_name_ecr": github_workflow_file_name_ecr,
			"github_workflow_name_ecr":      github_workflow_name_ecr,
			"github_workflow_file_name_env": github_workflow_file_name_env,
			"github_workflow_name_env":      github_workflow_name_env,
			"github_workflow_file_name_ecs": github_workflow_file_name_ecs,
			"github_workflow_name_ecs":      github_workflow_name_ecs,
			"github_organization":           github_organization,
			"github_repository":             github_repository,
			"github_branch":                 github_branch,

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

	privateInstanceIPMongodb := terraform.Output(t, terraformOptions, "ec2_instance_mongodb_private_ip")

	// defer func() {
	// 	if r := recover(); r != nil {
	// 		// destroy all resources if panic
	// 		terraform.Destroy(t, terraformOptions)
	// 	}
	// 	test_structure.RunTestStage(t, "cleanup_scraper_backend", func() {
	// 		terraform.Destroy(t, terraformOptions)
	// 	})
	// }()

	// TODO: plan test
	// https://github.com/gruntwork-io/terratest/blob/master/test/terraform_aws_example_plan_test.go

	test_structure.RunTestStage(t, "deploy_scraper_backend", func() {
		terraform.InitAndApply(t, terraformOptions)
	})

	ecrInitialImagesAmount := getEcrImagesAmount(t, common_name, account_region)
	fmt.Printf("\nInitial amount of images in ECR registry: %d\n", ecrInitialImagesAmount)

	runGithubWorkflow(
		github_organization,
		github_repository,
		github_branch,
		account_id,
		account_region,
		common_name,
		privateInstanceIPMongodb,
	)

	test_structure.RunTestStage(t, "validate_ecr", func() {
		testEcr(t, common_name, account_region, ecrInitialImagesAmount+1)
	})

	test_structure.RunTestStage(t, "validate_ecs", func() {
		testEcs(t, common_name, account_region, common_name, strconv.Itoa(cpu), strconv.Itoa(memory))
	})

	// TODO: test backend / route or healthcheck
}

// Run Github workflow CI/CD to push images on ECR and update ECS
func runGithubWorkflow(
	github_organization string,
	github_repository string,
	github_branch string,
	account_id string,
	account_region string,
	common_name string,
	privateInstanceIPMongodb string,
) {

	bashCode := fmt.Sprintf(`
		gh workflow run cicd.yml --repo %s/%s --ref %s\
		-f aws-account-id=%s \
		-f aws-region=%s \
		-f common-name=%s \
		-f mongodb-adress=%s
		`,
		github_organization,
		github_repository,
		github_branch,
		account_id,
		account_region,
		common_name,
		privateInstanceIPMongodb,
	)
	bashCode += fmt.Sprintf(`
	echo "Sleep 10 seconds for spawning action"
	sleep 10s
	echo "Continue to check the status"
	# while workflow status == in_progress, wait
	workflowStatus="preparing"
	while [ "${workflowStatus}" != "completed" ]
	do
		workflowStatus=$(gh run list --repo %s/%s --branch %s --workflow %s --limit 1 | awk '{print $1}')
		echo $workflowStatus
		if [[ $workflowStatus  =~ "could not find any workflows" ]]; then exit 1; fi
		echo "Waiting for status workflow to complete: "${workflowStatus}
		sleep 5s
	done
	echo "Workflow finished: "${workflowStatus}
	`,
		github_organization,
		github_repository,
		github_branch,
		"CI/CD",
	)
	command := test_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	shellOutput := test_shell.RunCommandAndGetOutput(t, command)
	fmt.Printf("\nWorkflow shell output: %s\n", shellOutput)
}

func getEcrImagesAmount(t *testing.T, common_name, account_region string) int {
	bashCode := fmt.Sprintf(`aws ecr list-images --repository-name %s --region %s --output text --query "imageIds[].[imageTag]" | wc -l`,
		common_name,
		account_region,
	)
	command := test_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	output := strings.TrimSpace(test_shell.RunCommandAndGetOutput(t, command))
	ecrImagesAmount, err := strconv.Atoi(output)
	if err != nil {
		t.Errorf(fmt.Sprintf("String to int conversion failed: %s", output))
	}
	return ecrImagesAmount
}

func testEcr(t *testing.T, common_name, account_region string, expectedImagesAmount int) {
	currentImagesAmount := getEcrImagesAmount(t, common_name, account_region)
	assert.Equal(t, expectedImagesAmount, currentImagesAmount)
}

// https://github.com/gruntwork-io/terratest/blob/master/test/terraform_aws_ecs_example_test.go
func testEcs(t *testing.T, family_name, account_region, common_name, cpu, memory string) {
	// cluster
	cluster := aws.GetEcsCluster(t, account_region, common_name)
	services_amount := int64(1)
	assert.Equal(t, services_amount, awsSDK.Int64Value(cluster.ActiveServicesCount))

	service := aws.GetEcsService(t, account_region, common_name, common_name)
	service_desired_count := int64(1)
	assert.Equal(t, service_desired_count, awsSDK.Int64Value(service.DesiredCount))
	assert.Equal(t, "EC2", awsSDK.StringValue(service.LaunchType))

	// task definition
	bashCode := fmt.Sprintf(`aws ecs list-task-definitions \
		--region %s \
		--family-prefix %s \
		--sort DESC \
		--query 'taskDefinitionArns[0]' \
		--output text`,
		account_region,
		family_name,
	)
	command := test_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	latestTaskDefinitionArn := strings.TrimSpace(test_shell.RunCommandAndGetOutput(t, command))
	fmt.Printf("\nlatestTaskDefinitionArn = %s\n", latestTaskDefinitionArn)

	task := aws.GetEcsTaskDefinition(t, account_region, latestTaskDefinitionArn)
	assert.Equal(t, cpu, awsSDK.StringValue(task.Cpu))
	assert.Equal(t, memory, awsSDK.StringValue(task.Memory))

	// task version
	bashCode = fmt.Sprintf(`aws ecs list-tasks \
		--region %s \
		--cluster %s \
		--query 'taskArns[]' \
		--output text`,
		account_region,
		common_name,
	)
	command = test_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	runningTaskArns := strings.Fields(test_shell.RunCommandAndGetOutput(t, command))
	fmt.Printf("\runningTaskArns = %v\n", runningTaskArns)

	if len(runningTaskArns) == 0 {
		t.Errorf("No tasks launched")
	}

	for _, runningTaskArn := range runningTaskArns {
		assert.Equal(t, latestTaskDefinitionArn, runningTaskArn, "The tasks ARN need to match otherwise the latest version is not the one running")
	}
}
