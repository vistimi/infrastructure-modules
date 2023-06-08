package microservice

import (
	"crypto/tls"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	awsSDK "github.com/aws/aws-sdk-go/aws"
	"github.com/likexian/gokit/assert"

	terratest_aws "github.com/gruntwork-io/terratest/modules/aws"
	terratest_http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	terratest_logger "github.com/gruntwork-io/terratest/modules/logger"
	terratest_shell "github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratest_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

var (
	AccountName   = os.Getenv("AWS_PROFILE")
	AccountId     = os.Getenv("AWS_ID")
	AccountRegion = os.Getenv("AWS_REGION")
)

const (
	serviceTaskDesiredCountInit  = 0 // before CI/CD pileline
	ServiceTaskDesiredCountFinal = 1 // one for each fargate capacity provider
	TaskDefinitionImageTag       = "latest"

	// https://docs.aws.amazon.com/AmazonECS/latest/developerguide/memory-management.html#ecs-reserved-memory
	ECSReservedMemory = 100
)

type EC2Instance struct {
	Name          string
	Cpu           int
	Memory        int
	MemoryAllowed int
}

var (
	// for amazon 2023 at least
	T3Small = EC2Instance{
		Name:          "t3.small",
		Cpu:           2048,
		Memory:        2048,
		MemoryAllowed: 1780, // TODO: double check under infra of cluster + ECSReservedMemory
	}
	T3Medium = EC2Instance{
		Name:          "t3.medium",
		Cpu:           2048,
		Memory:        4096,
		MemoryAllowed: 3828,
	}
)

type GithubProjectInformation struct {
	Organization     string
	Repository       string
	Branch           string
	WorkflowFilename string
	WorkflowName     string
	HealthCheckPath  string
}

type EndpointTest struct {
	Url                 string
	ExpectedStatus      int
	ExpectedBody        *string
	MaxRetries          int
	SleepBetweenRetries time.Duration
}

func SetupOptionsMicroservice(t *testing.T, projectName, serviceName string) (*terraform.Options, string) {
	rand.Seed(time.Now().UnixNano())

	// setup terraform override variables
	bashCode := `gh auth login --with-token %s;terragrunt init;`
	command := terratest_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	terratest_shell.RunCommandAndGetOutput(t, command)

	// global variables
	id := RandomID(8)
	environment_name := fmt.Sprintf("%s-%s", os.Getenv("ENVIRONMENT_NAME"), id)
	common_name := strings.ToLower(fmt.Sprintf("%s-%s-%s", projectName, serviceName, environment_name)) // update var
	common_tags := map[string]string{
		"Account":     AccountName,
		"Region":      AccountRegion,
		"Project":     projectName,
		"Service":     serviceName,
		"Environment": environment_name,
	}
	common_tags_json, err := json.Marshal(common_tags)
	if err != nil {
		terratest_logger.Log(t, err)
	}

	// end variables
	// https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html#enable_task_iam_roles
	// ECS_ENABLE_TASK_IAM_ROLE=true // Uses IAM roles for tasks for containers with the bridge and default network modes
	// ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true // Uses IAM roles for tasks for containers with the host network mode

	// awslogs log driver, Amazon ECS container instances require at least version 1.9.0 of the container agent
	// sudo yum update -y ecs-init && sudo systemctl restart docker
	// ECS_AVAILABLE_LOGGING_DRIVERS='["json-file","awslogs"]'
	// ECS_ENABLE_AWSLOGS_EXECUTIONROLE_OVERRIDE=true # https://github.com/aws/amazon-ecs-agent/issues/1395#issuecomment-391930395

	user_data := fmt.Sprintf(`#!/bin/bash
	cat <<'EOF' >> /etc/ecs/ecs.config
	ECS_CLUSTER=%s
	ECS_LOGLEVEL=debug
	ECS_CONTAINER_INSTANCE_TAGS=%s
	ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true
	ECS_ENABLE_SPOT_INSTANCE_DRAINING=true
	ECS_RESERVED_MEMORY=%d
	EOF
	`, common_name, common_tags_json, ECSReservedMemory)

	// vpc variables
	vpcId := terraform.Output(t, &terraform.Options{TerraformDir: "../../vpc"}, "vpc_id")
	defaultSecurityGroupId := terraform.Output(t, &terraform.Options{TerraformDir: "../../vpc"}, "default_security_group_id")

	bucketEnvName := fmt.Sprintf("%s-%s", common_name, "env")

	options := &terraform.Options{
		Vars: map[string]any{
			"common_name": common_name,
			"common_tags": common_tags,
			"vpc": map[string]any{
				"id":                 vpcId,
				"security_group_ids": []string{defaultSecurityGroupId},
				"tier":               "Public",
			},

			"log": map[string]any{
				"retention_days": 1,
				"prefix":         "aws/ecs",
			},

			"service_task_desired_count": serviceTaskDesiredCountInit,
			"user_data":                  user_data,

			"task_definition": map[string]any{
				"env_bucket_name":    bucketEnvName,
				"registry_image_tag": TaskDefinitionImageTag,
			},

			"bucket_env": map[string]any{
				"name":          bucketEnvName,
				"force_destroy": true,
				"versioning":    false,
			},

			"ecr": map[string]any{
				"image_keep_count": 1,
				"force_destroy":    true,
			},
		},
	}
	return options, common_name
}

var letterRunes = []rune("abcdefghijklmnopqrstuvwxyz")

func RandomID(n int) string {
	b := make([]rune, n)
	for i := range b {
		b[i] = letterRunes[rand.Intn(len(letterRunes))]
	}
	return string(b)
}

func TestMicroservice(t *testing.T, terraformOptions *terraform.Options, githubInformations GithubProjectInformation) {
	// // TODO: plan test for updates
	// // https://github.com/gruntwork-io/terratest/blob/master/test/terraform_aws_example_plan_test.go

	common_name, ok := terraformOptions.Vars["common_name"].(string)
	if !ok {
		terratest_logger.Log(t, "terraformOptions misses common_name as string")
	}

	terratest_structure.RunTestStage(t, "validate_ecr", func() {
		testEcr(t, common_name, AccountRegion)
	})

	terratest_structure.RunTestStage(t, "validate_ecs", func() {
		testEcs(t, common_name, AccountRegion, common_name, ServiceTaskDesiredCountFinal)
	})
}

// Run Github workflow CI/CD to push images on ECR and update ECS
func RunGithubWorkflow(
	t *testing.T,
	githubInformations GithubProjectInformation,
	commandStartWorkflow string,
) {

	bashCode := fmt.Sprintf(`
		%s
		echo "Sleep 10 seconds for spawning action"; sleep 10s
		echo "Continue to check the status"
		# wait while workflow is in_progress
		workflowStatus="preparing"
		while [ "${workflowStatus}" != "completed" ]
		do
			workflowStatus=$(gh run list --repo %s/%s --branch %s --workflow %s --limit 1 | awk '{print $1}'); echo $workflowStatus
			if [[ $workflowStatus  =~ "could not find any workflows" ]]; then exit 1; fi
			echo "Waiting for status workflow to complete: "${workflowStatus}
			sleep 30s
		done
		echo "Workflow finished: $workflowStatus"
		echo "Sleep 10 seconds"; sleep 10s
	`,
		commandStartWorkflow,
		githubInformations.Organization,
		githubInformations.Repository,
		githubInformations.Branch,
		githubInformations.WorkflowName,
	)
	command := terratest_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	terratest_shell.RunCommandAndGetOutput(t, command)
}

func testEcr(t *testing.T, common_name, account_region string) {
	bashCode := fmt.Sprintf(`aws ecr list-images --repository-name %s --region %s --output text --query "imageIds[].[imageTag]" | wc -l`,
		common_name,
		account_region,
	)
	command := terratest_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	output := strings.TrimSpace(terratest_shell.RunCommandAndGetOutput(t, command))
	ecrImagesAmount, err := strconv.Atoi(output)
	if err != nil {
		terratest_logger.Log(t, fmt.Sprintf("String to int conversion failed: %s", output))
	}

	assert.Equal(t, 1, ecrImagesAmount, fmt.Sprintf("No image published to repository: %v", ecrImagesAmount))
}

// https://github.com/gruntwork-io/terratest/blob/master/test/terraform_aws_ecs_example_test.go
func testEcs(t *testing.T, family_name, account_region, common_name string, service_task_desired_count int) {
	// cluster
	cluster := terratest_aws.GetEcsCluster(t, account_region, common_name)
	services_amount := int64(1)
	assert.Equal(t, services_amount, awsSDK.Int64Value(cluster.ActiveServicesCount))

	// tasks in service
	service := terratest_aws.GetEcsService(t, account_region, common_name, common_name)
	service_desired_count := int64(service_task_desired_count)
	assert.Equal(t, service_desired_count, awsSDK.Int64Value(service.DesiredCount), "amount of running tasks in service do not match the expected value")

	// latest task definition
	bashCode := fmt.Sprintf(`
	aws ecs list-task-definitions \
		--region %s \
		--family-prefix %s \
		--sort DESC \
		--query 'taskDefinitionArns[0]' \
		--output text
	`,
		account_region,
		family_name,
	)
	command := terratest_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	latestTaskDefinitionArn := strings.TrimSpace(terratest_shell.RunCommandAndGetOutput(t, command))
	fmt.Printf("\n\nlatestTaskDefinitionArn = %s\n\n", latestTaskDefinitionArn)

	// task := terratest_aws.GetEcsTaskDefinition(t, account_region, latestTaskDefinitionArn)
	// assert.Equal(t, cpu, awsSDK.StringValue(task.Cpu))
	// assert.Equal(t, memory, awsSDK.StringValue(task.Memory))

	// running tasks
	bashCode = fmt.Sprintf(`
	aws ecs list-tasks \
		--region %s \
		--cluster %s \
		--query 'taskArns[]' \
		--output text
	`,
		account_region,
		common_name,
	)
	command = terratest_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	runningTaskArns := strings.Fields(terratest_shell.RunCommandAndGetOutput(t, command))
	fmt.Printf("\n\nrunningTaskArns = %v\n\n", runningTaskArns)
	if len(runningTaskArns) == 0 {
		terratest_logger.Log(t, "No running tasks")
		return
	}

	// tasks definition versions
	runningTasks := ``
	for _, runningTaskArn := range runningTaskArns {
		runningTasks += fmt.Sprintf(`%s `, runningTaskArn)
	}
	bashCode = fmt.Sprintf(`
	aws ecs describe-tasks \
		--region %s \
		--cluster %s \
		--tasks %s \
		--query 'tasks[].[taskDefinitionArn]' \
		--output text
	`,
		account_region,
		common_name,
		runningTasks,
	)
	command = terratest_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	runningTaskDefinitionArns := strings.Fields(terratest_shell.RunCommandAndGetOutput(t, command))
	fmt.Printf("\n\nrunningTaskDefinitionArns = %v\n\n", runningTaskDefinitionArns)
	if len(runningTaskDefinitionArns) == 0 {
		terratest_logger.Log(t, "No running tasks definition")
		return
	}

	for _, runningTaskDefinitionArn := range runningTaskDefinitionArns {
		if latestTaskDefinitionArn != runningTaskDefinitionArn {
			terratest_logger.Log(t, "The tasks ARN need to match otherwise the latest version is not the one running")
		}
	}
}

// func testCapacityProviders(t *testing.T, account_region, common_name string) {
// 	cluster := terratest_aws.GetEcsCluster(t, account_region, common_name)
// 	cluster.CapacityProviders
// 	cluster.RegisteredContainerInstancesCount

// 	service := terratest_aws.GetEcsService(t, account_region, common_name, common_name)
// 	for _, lb := range(service.LoadBalancers) {
// 		lb.
// 	}

// 	service_desired_count := int64(1)
// 	assert.Equal(t, service_desired_count, awsSDK.Int64Value(service.DesiredCount), "amount of running services do not match the expected value")

// 	// latest task definition
// 	bashCode := fmt.Sprintf(`aws ecs list-task-definitions \
// 		--region %s \
// 		--family-prefix %s \
// 		--sort DESC \
// 		--query 'taskDefinitionArns[0]' \
// 		--output text`,
// 		account_region,
// 		family_name,
// 	)
// 	command := terratest_shell.Command{
// 		Command: "bash",
// 		Args:    []string{"-c", bashCode},
// 	}
// 	latestTaskDefinitionArn := strings.TrimSpace(terratest_shell.RunCommandAndGetOutput(t, command))
// 	fmt.Printf("\nlatestTaskDefinitionArn = %s\n", latestTaskDefinitionArn)

// }

func TestRestEndpoints(t *testing.T, endpoints []EndpointTest) {
	tlsConfig := tls.Config{}
	for _, endpoint := range endpoints {
		if endpoint.ExpectedBody == nil {
			options := terratest_http_helper.HttpGetOptions{Url: endpoint.Url, TlsConfig: &tlsConfig, Timeout: 10}
			gotStatus, _ := terratest_http_helper.HttpGetWithOptions(t, options)
			for i := 0; i < endpoint.MaxRetries; i++ {
				if gotStatus == endpoint.ExpectedStatus {
					return
				}
				terratest_logger.Log(t, fmt.Sprintf("Response status do not match: expect %v, got %v", endpoint.ExpectedStatus, gotStatus))
				time.Sleep(time.Second * endpoint.SleepBetweenRetries)
			}
			t.Fatalf(`'HTTP GET to URL %s' unsuccessful after %d retries`, endpoint.Url, endpoint.MaxRetries)
		} else {
			terratest_http_helper.HttpGetWithRetry(t, endpoint.Url, &tlsConfig, endpoint.ExpectedStatus, *endpoint.ExpectedBody, endpoint.MaxRetries, endpoint.SleepBetweenRetries)
		}
	}
}

func CheckUrlPrefix(url string) string {
	if strings.HasPrefix(url, "http://") || strings.HasPrefix(url, "https://") {
		return url
	} else {
		return "http://" + url
	}
}
