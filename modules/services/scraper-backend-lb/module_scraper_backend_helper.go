package test

import (
	"crypto/tls"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
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

var (
	// global variables
	account_name   = os.Getenv("AWS_PROFILE")
	account_id     = os.Getenv("AWS_ID")
	account_region = os.Getenv("AWS_REGION")
	project_name   = "scraper"
	service_name   = "backend"

	// github variables
	GithubOrganization = "KookaS"
	GithubRepository   = "scraper-backend"
	// github_repository_id = "497233030"
	GithubBranch    = "master"
	HealthCheckPath = "/healthz"

	// end variables
	ecs_task_desired_count        = 1
	ecs_task_definition_image_tag = "latest"
	env_file_name                 = fmt.Sprintf("%s.env", GithubBranch)
	cpu                           = 256
	memory                        = 512
	// memory_reservation := 512
	listener_port     = 80
	listener_protocol = "HTTP"
	target_port       = 8080
	target_protocol   = "HTTP"
)

func SetupHttpOptions(t *testing.T) *terraform.Options {
	rand.Seed(time.Now().UnixNano())

	// setup
	bashCode := `terragrunt init;`
	command := test_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	test_shell.RunCommandAndGetOutput(t, command)

	// yml
	path, err := filepath.Abs("config_override.yml")
	if err != nil {
		t.Error(err)
	}
	configYml, err := ReadConfigFile(path)
	if err != nil {
		t.Error(err)
	}

	// global variables
	id := randomID(8)
	environment_name := fmt.Sprintf("%s-%s", os.Getenv("ENVIRONMENT_NAME"), id)
	common_name := strings.ToLower(fmt.Sprintf("%s-%s-%s", project_name, service_name, environment_name)) // update var
	common_tags := map[string]string{
		"Account":     account_name,
		"Region":      account_region,
		"Project":     project_name,
		"Service":     service_name,
		"Environment": environment_name,
	}
	common_tags_json, err := json.Marshal(common_tags)
	if err != nil {
		t.Error(err)
	}

	// end variables
	user_data := fmt.Sprintf(`#!/bin/bash
		cat <<'EOF' >> /etc/ecs/ecs.config
		ECS_CLUSTER=%s
		ECS_ENABLE_TASK_IAM_ROLE=true
		ECS_LOGLEVEL=debug
		ECS_AVAILABLE_LOGGING_DRIVERS='["json-file","awslogs"]'
		ECS_ENABLE_AWSLOGS_EXECUTIONROLE_OVERRIDE=true
		ECS_CONTAINER_INSTANCE_TAGS=%s
		ECS_ENABLE_SPOT_INSTANCE_DRAINING=true
		EOF`, common_name, common_tags_json)

	// vpc variables
	vpc_id := terraform.Output(t, &terraform.Options{TerraformDir: "../../vpc"}, "vpc_id")
	default_security_group_id := terraform.Output(t, &terraform.Options{TerraformDir: "../../vpc"}, "default_security_group_id")

	// yml variables
	var dynamodb_tables []map[string]any
	for _, db := range configYml.Databases {
		dynamodb_tables = append(dynamodb_tables, map[string]any{
			"name":             *db.Name,
			"primary_key_name": *db.PrimaryKeyName,
			"primary_key_type": *db.PrimaryKeyType,
			"sort_key_name":    *db.SortKeyName,
			"sort_key_type":    *db.SortKeyType,
		})
	}
	bucket_env_name_extension, ok := configYml.Buckets["env"]
	if !ok {
		t.Errorf("config.yml file missing buckets.env")
	}
	bucket_picture_name_extension, ok := configYml.Buckets["picture"]
	if !ok {
		t.Errorf("config.yml file missing buckets.picture")
	}
	bucket_env_name := fmt.Sprintf("%s-%s", common_name, *bucket_env_name_extension.Name)
	bucket_picture_name := fmt.Sprintf("%s-%s", common_name, *bucket_picture_name_extension.Name)

	return &terraform.Options{
		TerraformDir: "",
		Vars: map[string]interface{}{
			"vpc_id":                 vpc_id,
			"vpc_security_group_ids": []string{default_security_group_id},
			"common_name":            common_name,
			"common_tags":            common_tags,
			"force_destroy":          true,

			"ecs_task_definition_image_tag":       ecs_task_definition_image_tag,
			"ecs_logs_retention_in_days":          1,
			"listener_port":                       listener_port,
			"listener_protocol":                   listener_protocol,
			"target_port":                         target_port,
			"target_protocol":                     target_protocol,
			"target_capacity_cpu":                 70,
			"capacity_provider_base":              1,
			"capacity_provider_weight_on_demand":  20,
			"capacity_provider_weight_spot":       80,
			"user_data":                           user_data,
			"protect_from_scale_in":               false,
			"vpc_tier":                            "Public",
			"instance_type_on_demand":             "t2.micro",
			"min_size_on_demand":                  "0",
			"max_size_on_demand":                  "1",
			"desired_capacity_on_demand":          "0",
			"minimum_scaling_step_size_on_demand": "1",
			"maximum_scaling_step_size_on_demand": "1",
			"ami_ssm_architecture_on_demand":      "amazon-linux-2",
			"instance_type_spot":                  "t2.micro",
			"min_size_spot":                       "0",
			"max_size_spot":                       "1",
			"desired_capacity_spot":               "1",
			"minimum_scaling_step_size_spot":      "1",
			"maximum_scaling_step_size_spot":      "1",
			"ami_ssm_architecture_spot":           "amazon-linux-2",
			"ecs_task_definition_memory":          memory,
			// "ecs_task_definition_memory_reservation": memory_reservation,
			"ecs_task_definition_cpu": cpu,
			"ecs_task_desired_count":  ecs_task_desired_count,
			"env_file_name":           env_file_name,
			"bucket_env_name":         bucket_env_name,
			"port_mapping": []map[string]any{
				{
					"name":          "container-port",
					"hostPort":      target_port,
					"protocol":      "tcp",
					"containerPort": target_port,
				},
			},

			"repository_image_keep_count": 1,
			"health_check_path":           HealthCheckPath,

			"dynamodb_tables":      dynamodb_tables,
			"dynamodb_autoscaling": false,
			"bucket_picture_name":  bucket_picture_name,
		},
	}
}

func TestScraperBackend(t *testing.T, terraformOptions *terraform.Options) {
	// // TODO: plan test for updates
	// // https://github.com/gruntwork-io/terratest/blob/master/test/terraform_aws_example_plan_test.go

	common_name, ok := terraformOptions.Vars["common_name"].(string)
	if !ok {
		t.Errorf("terraformOptions misses common_name as string")
	}
	var ecrInitialImagesAmount int
	test_structure.RunTestStage(t, "deploy_scraper_backend", func() {
		terraform.InitAndApply(t, terraformOptions)
		ecrInitialImagesAmount = getEcrImagesAmount(t, common_name, account_region)
		fmt.Printf("\nInitial amount of images in ECR registry: %d\n", ecrInitialImagesAmount)
		runGithubWorkflow(
			t,
			GithubOrganization,
			GithubRepository,
			GithubBranch,
			account_id,
			account_name,
			account_region,
			common_name,
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
		testEndpoints(t, albDnsName, HealthCheckPath)
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
	task_desired_count string,
) {

	bashCode := fmt.Sprintf(`
		gh workflow run cicd.yml --repo %s/%s --ref %s\
		-f aws-account-id=%s \
		-f aws-account-name=%s \
		-f aws-region=%s \
		-f common-name=%s \
		-f task-desired-count=%s || exit 1
		`,
		github_organization,
		github_repository,
		github_branch,
		account_id,
		account_name,
		account_region,
		common_name,
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
		sleep 30s
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
	expectedBody := `"ok"`
	maxRetries := 3
	sleepBetweenRetries := 10 * time.Second
	http_helper.HttpGetWithRetry(t, instanceURL, &tlsConfig, expectedStatus, expectedBody, maxRetries, sleepBetweenRetries)

	// tags
	instanceURL = dnsURL + "/tags/wanted"
	tlsConfig = tls.Config{}
	expectedStatus = 200
	expectedBody = `[]` // empty dynamodb
	maxRetries = 5
	sleepBetweenRetries = 10 * time.Second
	http_helper.HttpGetWithRetry(t, instanceURL, &tlsConfig, expectedStatus, expectedBody, maxRetries, sleepBetweenRetries)
}
