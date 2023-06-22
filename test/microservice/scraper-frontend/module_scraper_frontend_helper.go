package scraper_frontend_test

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"strings"
	"testing"
	"time"

	"golang.org/x/exp/maps"

	"github.com/KookaS/infrastructure-modules/test/microservice"

	terratest_shell "github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratest_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	projectName = "scraper"
	serviceName = "frontend"

	listenerPort            = 80
	listenerProtocol        = "http"
	listenerProtocolVersion = "http"
	targetPort              = 3000
	targetProtocol          = "http"
	targetProtocolVersion   = "http"

	microservicePath = "../../../module/aws/microservice/scraper-frontend"
)

var (
	GithubProject = microservice.GithubProjectInformation{
		Organization:    "KookaS",
		Repository:      "scraper-frontend",
		Branch:          "master", // TODO: make it flexible for testing other branches
		HealthCheckPath: "/healthz",
		ImageTag:        "latest",
	}
)

func SetupOptionsProject(t *testing.T) (*terraform.Options, string) {

	// setup terraform override variables
	bashCode := fmt.Sprintf(`cd %s; terragrunt init;`, microservicePath)
	command := terratest_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	terratest_shell.RunCommandAndGetOutput(t, command)

	optionsMicroservice, commonName := microservice.SetupOptionsMicroservice(t, projectName, serviceName)

	optionsProject := &terraform.Options{
		TerraformDir: microservicePath,
		Vars:         map[string]any{},
	}

	maps.Copy(optionsProject.Vars, optionsMicroservice.Vars)
	maps.Copy(optionsProject.Vars["ecs"].(map[string]any), map[string]any{
		"traffic": map[string]any{
			"listener_port":             listenerPort,
			"listener_protocol":         listenerProtocol,
			"listener_protocol_version": listenerProtocolVersion,
			"target_port":               targetPort,
			"target_protocol":           targetProtocol,
			"target_protocol_version":   targetProtocolVersion,
			"health_check_path":         GithubProject.HealthCheckPath,
		},
	})
	envKey := fmt.Sprintf("%s.env", GithubProject.Branch)
	maps.Copy(optionsProject.Vars["ecs"].(map[string]any)["task_definition"].(map[string]any), map[string]any{
		"env_file_name":        envKey,
		"repository_name":      strings.ToLower(fmt.Sprintf("%s-%s-%s", GithubProject.Organization, GithubProject.Repository, GithubProject.Branch)),
		"repository_image_tag": GithubProject.ImageTag,
		"tmpfs": map[string]any{
			"ContainerPath": "/run/npm",
			"Size":          1024,
		},
		"environment": []map[string]any{
			{
				"name":  "TMPFS_NPM",
				"value": "/run/npm",
			},
		},
	})
	maps.Copy(optionsProject.Vars["bucket_env"].(map[string]any), map[string]any{
		"file_key":  envKey,
		"file_path": "override.env",
	})

	return optionsProject, commonName
}

func RunTest(t *testing.T, options *terraform.Options, commonName string) {
	options = terraform.WithDefaultRetryableErrors(t, options)

	defer func() {
		if r := recover(); r != nil {
			// destroy all resources if panic
			terraform.Destroy(t, options)
		}
		terratest_structure.RunTestStage(t, "cleanup_scraper_frontend", func() {
			terraform.Destroy(t, options)
		})
	}()

	terratest_structure.RunTestStage(t, "deploy_scraper_frontend", func() {
		terraform.InitAndApply(t, options)
	})

	microservice.TestMicroservice(t, options, GithubProject)

	// dnsUrl := terraform.Output(t, options, "alb_dns_name")
	jsonFile, err := os.Open(fmt.Sprintf("%s/terraform.tfstate", microservicePath))
	if err != nil {
		t.Fatal(err)
	}
	defer jsonFile.Close()
	byteValue, _ := ioutil.ReadAll(jsonFile)
	var result map[string]any
	json.Unmarshal([]byte(byteValue), &result)
	dnsUrl := result["outputs"].(map[string]any)["microservice"].(map[string]any)["value"].(map[string]any)["ecs"].(map[string]any)["elb"].(map[string]any)["lb_dns_name"].(string)
	dnsUrl = microservice.CheckUrlPrefix(dnsUrl)
	fmt.Printf("\n\nDNS = %s\n\n", dnsUrl)
	endpoints := []microservice.EndpointTest{
		{
			Url:                 microservice.CheckUrlPrefix(dnsUrl + GithubProject.HealthCheckPath),
			ExpectedStatus:      200,
			ExpectedBody:        nil,
			MaxRetries:          3,
			SleepBetweenRetries: 30 * time.Second,
		},
	}

	terratest_structure.RunTestStage(t, "validate_rest_endpoints", func() {
		microservice.TestRestEndpoints(t, endpoints)
	})
}
