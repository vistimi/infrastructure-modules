package microservice

import (
	"crypto/tls"
	"fmt"
	"math/rand"
	"os"
	"strings"
	"testing"
	"time"

	terratest_http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	terratest_logger "github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratest_structure "github.com/gruntwork-io/terratest/modules/test-structure"

	module_test "github.com/KookaS/infrastructure-modules/test/module"
)

var (
	AccountName   = os.Getenv("AWS_PROFILE")
	AccountId     = os.Getenv("AWS_ACCOUNT_ID")
	AccountRegion = os.Getenv("AWS_REGION")
)

const (
	vpcPath = "../../../module/aws/vpc" // path for microservices

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
		MemoryAllowed: 1801, // TODO: double check under infra of cluster + ECSReservedMemory
	}
	T3Medium = EC2Instance{
		Name:          "t3.medium",
		Cpu:           2048,
		Memory:        4096,
		MemoryAllowed: 3828,
	}
)

type GithubProjectInformation struct {
	Organization string
	Repository   string
	Branch       string
	// WorkflowFilename string
	// WorkflowName     string
	HealthCheckPath string
	ImageTag        string
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

	// global variables
	id := RandomID(8)
	environment_name := fmt.Sprintf("%s-%s", os.Getenv("ENVIRONMENT_NAME"), id)
	commonName := strings.ToLower(fmt.Sprintf("%s-%s-%s", projectName, serviceName, environment_name))
	commonTags := map[string]string{
		"Account":     AccountName,
		"Region":      AccountRegion,
		"Project":     projectName,
		"Service":     serviceName,
		"Environment": environment_name,
	}

	// // // vpc variables
	// // vpc := terraform.Output(t, &terraform.Options{TerraformDir: "../../vpc"}, "vpc")
	// jsonFile, err := os.Open(fmt.Sprintf("%s/terraform.tfstate", vpcPath))
	// if err != nil {
	// 	t.Fatal(err)
	// }
	// defer jsonFile.Close()
	// byteValue, _ := ioutil.ReadAll(jsonFile)
	// var result map[string]any
	// json.Unmarshal([]byte(byteValue), &result)
	// vpcId := result["outputs"].(map[string]any)["vpc"].(map[string]any)["value"].(map[string]any)["vpc_id"].(string)
	// defaultSecurityGroupId := result["outputs"].(map[string]any)["vpc"].(map[string]any)["value"].(map[string]any)["default_security_group_id"].(string)

	bucketEnvName := fmt.Sprintf("%s-%s", commonName, "env")

	options := &terraform.Options{
		Vars: map[string]any{
			"common_name": commonName,
			"common_tags": commonTags,

			"microservice": map[string]any{
				"ecs": map[string]any{
					"log": map[string]any{
						"retention_days": 1,
						"prefix":         "aws/ecs",
					},
					"task_definition": map[string]any{
						"env_bucket_name": bucketEnvName,
					},
				},
				"bucket_env": map[string]any{
					"name":          bucketEnvName,
					"force_destroy": true,
					"versioning":    false,
				},
			},
		},
	}
	return options, commonName
}

var letterRunes = []rune("abcdefghijklmnopqrstuvwxyz")

func RandomID(n int) string {
	b := make([]rune, n)
	for i := range b {
		b[i] = letterRunes[rand.Intn(len(letterRunes))]
	}
	return string(b)
}

func TestMicroservice(t *testing.T, terraformOptions *terraform.Options, githubInformations GithubProjectInformation, ServiceTaskDesiredCount int64) {
	// // TODO: plan test for updates
	// // https://github.com/gruntwork-io/terratest/blob/master/test/terraform_aws_example_plan_test.go

	commonName, ok := terraformOptions.Vars["common_name"].(string)
	if !ok {
		t.Fatal("terraformOptions misses common_name as string")
	}

	terratest_structure.RunTestStage(t, "validate_ecs", func() {
		serviceCount := int64(1)
		module_test.TestEcs(t, AccountRegion, commonName, commonName, serviceCount, ServiceTaskDesiredCount)
	})
}

func TestRestEndpoints(t *testing.T, endpoints []EndpointTest) {
	sleep := time.Second * 30
	terratest_logger.Log(t, fmt.Sprintf("Sleeping before testing endpoints %s...", sleep))
	time.Sleep(sleep)

	tlsConfig := tls.Config{}
	for _, endpoint := range endpoints {
		options := terratest_http_helper.HttpGetOptions{Url: endpoint.Url, TlsConfig: &tlsConfig, Timeout: 10}
		expectedBody := ""
		if endpoint.ExpectedBody != nil {
			expectedBody = *endpoint.ExpectedBody
		}
		for i := 0; i <= endpoint.MaxRetries; i++ {
			gotStatus, gotBody := terratest_http_helper.HttpGetWithOptions(t, options)
			terratest_logger.Log(t, fmt.Sprintf(`
			got status:: %d
			expected status:: %d
			`, gotStatus, endpoint.ExpectedStatus))
			if endpoint.ExpectedBody != nil {
				terratest_logger.Log(t, fmt.Sprintf(`
			got body:: %s
			expected body:: %s
			`, gotBody, expectedBody))
			}
			if gotStatus == endpoint.ExpectedStatus && (endpoint.ExpectedBody == nil || (endpoint.ExpectedBody != nil && gotBody == expectedBody)) {
				terratest_logger.Log(t, `'HTTP GET to URL %s' successful`, endpoint.Url)
				return
			}
			if i == endpoint.MaxRetries {
				t.Fatalf(`'HTTP GET to URL %s' unsuccessful after %d retries`, endpoint.Url, endpoint.MaxRetries)
			}
			terratest_logger.Log(t, fmt.Sprintf("Sleeping %s...", endpoint.SleepBetweenRetries))
			time.Sleep(endpoint.SleepBetweenRetries)
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
