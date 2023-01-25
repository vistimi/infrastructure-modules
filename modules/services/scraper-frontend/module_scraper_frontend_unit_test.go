package test

import (
	"crypto/tls"
	"fmt"
	"math/rand"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	awsSDK "github.com/aws/aws-sdk-go/aws"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	test_shell "github.com/gruntwork-io/terratest/modules/shell"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func Test_Unit_TerraformScraperFrontend(t *testing.T) {
	t.Parallel()
	rand.Seed(time.Now().UnixNano())

	// init
	bashCode := `terragrunt init;`
	command := test_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	test_shell.RunCommandAndGetOutput(t, command)

	// vpc variables
	vpc_id := terraform.Output(t, &terraform.Options{TerraformDir: "../../vpc"}, "vpc_id")
	default_security_group_id := terraform.Output(t, &terraform.Options{TerraformDir: "../../vpc"}, "default_security_group_id")

	// global variables
	id := randomID(8)
	account_name := os.Getenv("AWS_PROFILE")
	account_id := os.Getenv("AWS_ID")
	account_region := os.Getenv("AWS_REGION")
	project_name := "scraper"
	service_name := "frontend"
	environment_name := fmt.Sprintf("%s-%s", os.Getenv("ENVIRONMENT_NAME"), id)
	common_name := strings.ToLower(fmt.Sprintf("%s-%s-%s", project_name, service_name, environment_name))

	// end
	listener_port := 80
	listener_protocol := "HTTP"
	target_port := 3000
	target_protocol := "HTTP"
	user_data := fmt.Sprintf("#!/bin/bash\necho ECS_CLUSTER=%s >> /etc/ecs/ecs.config;", common_name)

	ecs_execution_role_name := fmt.Sprintf("%s-ecs-execution", common_name)
	ecs_task_container_role_name := fmt.Sprintf("%s-ecs-task-container", common_name)
	ecs_task_container_s3_env_policy_name := fmt.Sprintf("%s-ecs-task-container-s3-env", common_name)
	ecs_task_desired_count := 1
	ecs_task_definition_image_tag := "latest"
	env_file_name := ".env"
	bucket_env_name := fmt.Sprintf("%s-env", common_name)
	cpu := 2048
	memory := 1024
	memory_reservation := 1000

	// backend_dns := "dns_adress_test" //FIXME:
	backend_dns := "http://scraper-backend-test-kurnqcbt-1930982203.us-east-1.elb.amazonaws.com/"
	github_organization := "KookaS"
	github_repository := "scraper-frontend"
	github_branch := "production"
	health_check_path := "/healthz"
	github_repository_id := "?????"

	// options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "",
		Vars: map[string]interface{}{
			"account_region":         account_region,
			"account_id":             account_id,
			"account_name":           account_name,
			"vpc_id":                 vpc_id,
			"vpc_security_group_ids": []string{default_security_group_id},
			"common_name":            common_name,
			"common_tags": map[string]string{
				"Account":     account_name,
				"Region":      account_region,
				"Project":     project_name,
				"Service":     service_name,
				"Environment": environment_name,
			},
			"force_destroy": true,

			"ecs_execution_role_name":                ecs_execution_role_name,
			"ecs_task_container_role_name":           ecs_task_container_role_name,
			"ecs_task_definition_image_tag":          ecs_task_definition_image_tag,
			"ecs_task_container_s3_env_policy_name":  ecs_task_container_s3_env_policy_name,
			"ecs_logs_retention_in_days":             1,
			"listener_port":                          listener_port,
			"listener_protocol":                      listener_protocol,
			"target_port":                            target_port,
			"target_protocol":                        target_protocol,
			"target_capacity_cpu":                    70,
			"capacity_provider_base":                 1,
			"capacity_provider_weight_on_demand":     20,
			"capacity_provider_weight_spot":          80,
			"user_data":                              user_data,
			"protect_from_scale_in":                  false,
			"vpc_tier":                               "Public",
			"instance_type_on_demand":                "t4g.micro",
			"min_size_on_demand":                     "1",
			"max_size_on_demand":                     "1",
			"desired_capacity_on_demand":             "1",
			"maximum_scaling_step_size_on_demand":    "1",
			"minimum_scaling_step_size_on_demand":    "1",
			"ami_ssm_architecture_on_demand":         "amazon-linux-2-arm64",
			"instance_type_spot":                     "t4g.micro",
			"min_size_spot":                          "0",
			"max_size_spot":                          "0",
			"desired_capacity_spot":                  "0",
			"maximum_scaling_step_size_spot":         "1",
			"minimum_scaling_step_size_spot":         "1",
			"ami_ssm_architecture_spot":              "amazon-linux-2-arm64",
			"ecs_task_definition_memory":             memory,
			"ecs_task_definition_memory_reservation": memory_reservation,
			"ecs_task_definition_cpu":                cpu,
			"ecs_task_desired_count":                 ecs_task_desired_count,
			"env_file_name":                          env_file_name,
			"bucket_env_name":                        bucket_env_name,
			"port_mapping": []map[string]any{
				{
					"hostPort":      3000,
					"protocol":      "tcp",
					"containerPort": 3000,
				},
			},

			"repository_image_keep_count": 1,
			"github_organization":         github_organization,
			"github_repository":           github_repository,
			"github_repository_id":        github_repository_id,
			"github_branch":               github_branch,
			"health_check_path":           health_check_path,
		},
	})

	// defer func() {
	// 	if r := recover(); r != nil {
	// 		// destroy all resources if panic
	// 		terraform.Destroy(t, terraformOptions)
	// 	}
	// 	test_structure.RunTestStage(t, "cleanup_scraper_frontend", func() {
	// 		terraform.Destroy(t, terraformOptions)
	// 	})
	// }()

	// TODO: plan test for updates
	// https://github.com/gruntwork-io/terratest/blob/master/test/terraform_aws_example_plan_test.go

	var ecrInitialImagesAmount int
	test_structure.RunTestStage(t, "deploy_scraper_frontend", func() {
		terraform.InitAndApply(t, terraformOptions)
		ecrInitialImagesAmount = getEcrImagesAmount(t, common_name, account_region)
		fmt.Printf("\nInitial amount of images in ECR registry: %d\n", ecrInitialImagesAmount)
		runGithubWorkflow(
			t,
			github_organization,
			github_repository,
			github_branch,
			account_id,
			account_name,
			account_region,
			common_name,
			backend_dns,
			strconv.Itoa(ecs_task_desired_count),
		)
	})

	albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")

	test_structure.RunTestStage(t, "validate_ecr", func() {
		testEcr(t, common_name, account_region, ecrInitialImagesAmount+1)
	})

	test_structure.RunTestStage(t, "validate_ecs", func() {
		testEcs(t, common_name, account_region, common_name, strconv.Itoa(cpu), strconv.Itoa(memory))
	})

	test_structure.RunTestStage(t, "validate_endpoints", func() {
		albDnsName = "http://" + albDnsName
		testEndpoints(t, albDnsName, health_check_path)
	})

	fmt.Printf("\n\nDNS: %s\n\n", terraform.Output(t, terraformOptions, "alb_dns_name"))
}

var letterRunes = []rune("abcdefghijklmnopqrstuvwxyz")

func randomID(n int) string {
	b := make([]rune, n)
	for i := range b {
		b[i] = letterRunes[rand.Intn(len(letterRunes))]
	}
	return string(b)
}

// Run Github workflow CI/CD to push images on ECR and update ECS
func runGithubWorkflow(
	t *testing.T,
	github_organization,
	github_repository,
	github_branch,
	account_id,
	account_name,
	account_region,
	common_name,
	backend_dns,
	task_desired_count string,
) {

	bashCode := fmt.Sprintf(`
		gh workflow run cicd.yml --repo %s/%s --ref %s\
		-f aws-account-id=%s \
		-f aws-account-name=%s \
		-f aws-region=%s \
		-f common-name=%s \
		-f backend-dns=%s \
		-f task-desired-count=%s || exit 1
		`,
		github_organization,
		github_repository,
		github_branch,
		account_id,
		account_name,
		account_region,
		common_name,
		backend_dns,
		task_desired_count,
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
	echo "Workflow finished: $workflowStatus"
	sleep 10s
	echo "Sleep 10 seconds"
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
	test_shell.RunCommandAndGetOutput(t, command)
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
	assert.Equal(t, expectedImagesAmount, currentImagesAmount, "Amount of images present in the ECR repository do not match")
}

// https://github.com/gruntwork-io/terratest/blob/master/test/terraform_aws_ecs_example_test.go
func testEcs(t *testing.T, family_name, account_region, common_name, cpu, memory string) {
	// cluster
	cluster := aws.GetEcsCluster(t, account_region, common_name)
	services_amount := int64(1)
	assert.Equal(t, services_amount, awsSDK.Int64Value(cluster.ActiveServicesCount))

	service := aws.GetEcsService(t, account_region, common_name, common_name)
	service_desired_count := int64(1)
	assert.Equal(t, service_desired_count, awsSDK.Int64Value(service.DesiredCount), "amount of running services do not match the expected value")

	// latest task definition
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

	// running tasks
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
	fmt.Printf("\nrunningTaskArns = %v\n", runningTaskArns)
	if len(runningTaskArns) == 0 {
		t.Errorf("No running tasks")
		return
	}

	// tasks definition versions
	runningTasks := ``
	for _, runningTaskArn := range runningTaskArns {
		runningTasks += fmt.Sprintf(`%s `, runningTaskArn)
	}
	bashCode = fmt.Sprintf(`aws ecs describe-tasks \
		--region %s \
		--cluster %s \
		--tasks %s \
		--query 'tasks[].[taskDefinitionArn]' \
		--output text`,
		account_region,
		common_name,
		runningTasks,
	)
	command = test_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	runningTaskDefinitionArns := strings.Fields(test_shell.RunCommandAndGetOutput(t, command))
	fmt.Printf("\nrunningTaskDefinitionArns = %v\n", runningTaskDefinitionArns)
	if len(runningTaskDefinitionArns) == 0 {
		t.Errorf("No running tasks definition")
		return
	}

	for _, runningTaskDefinitionArn := range runningTaskDefinitionArns {
		assert.Equal(t, latestTaskDefinitionArn, runningTaskDefinitionArn, "The tasks ARN need to match otherwise the latest version is not the one running")
	}
}

func testEndpoints(t *testing.T, dnsURL, healthCheckPath string) {
	// healthcheck
	instanceURL := dnsURL + healthCheckPath
	tlsConfig := tls.Config{}
	expectedStatus := 200
	options := http_helper.HttpGetOptions{Url: instanceURL, TlsConfig: &tlsConfig, Timeout: 10}
	gotStatus, _ := http_helper.HttpGetWithOptions(t, options)
	assert.Equal(t, expectedStatus, gotStatus, "The status of the request don't match")
}
