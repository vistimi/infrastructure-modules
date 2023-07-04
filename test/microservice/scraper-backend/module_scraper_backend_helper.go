package scraper_backend_test

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"golang.org/x/exp/maps"

	"github.com/KookaS/infrastructure-modules/test/microservice"
	"github.com/KookaS/infrastructure-modules/test/util"

	terratest_shell "github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratest_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	projectName = "scraper"
	serviceName = "backend"

	listenerPort            = 80
	listenerProtocol        = "http"
	listenerProtocolVersion = "http"
	targetPort              = 8080
	targetProtocol          = "http"
	targetProtocolVersion   = "http"

	microservicePath = "../../../module/aws/microservice/scraper-backend"
)

var (
	GithubProject = microservice.GithubProjectInformation{
		Organization:    "KookaS",
		Repository:      "scraper-backend",
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

	// override.env
	bashCode = fmt.Sprintf("echo COMMON_NAME=%s >> %s/override.env", commonName, microservicePath)
	command = terratest_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	terratest_shell.RunCommandAndGetOutput(t, command)

	// yml
	path, err := filepath.Abs("config_override.yml")
	if err != nil {
		t.Error(err)
	}
	configYml, err := ReadConfigFile(path)
	if err != nil {
		t.Error(err)
	}

	// yml variables
	var dynamodb_tables []map[string]any
	for _, db := range configYml.Databases {
		dynamodb_tables = append(dynamodb_tables, map[string]any{
			"name":                 *db.Name,
			"primary_key_name":     *db.PrimaryKeyName,
			"primary_key_type":     *db.PrimaryKeyType,
			"sort_key_name":        *db.SortKeyName,
			"sort_key_type":        *db.SortKeyType,
			"predictable_workload": false,
		})
	}
	bucket_picture_name_extension, ok := configYml.Buckets["picture"]
	if !ok {
		t.Errorf("config.yml file missing buckets.picture")
	}
	bucket_picture_name := fmt.Sprintf("%s-%s", commonName, *bucket_picture_name_extension.Name)

	optionsProject := &terraform.Options{
		TerraformDir: microservicePath,
		Vars: map[string]any{
			"dynamodb_tables": dynamodb_tables,
			"bucket_picture": map[string]any{
				"name":          bucket_picture_name,
				"force_destroy": true,
				"versioning":    false,
			},
		},
	}

	maps.Copy(optionsProject.Vars, optionsMicroservice.Vars)
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any), map[string]any{
		"vpc": map[string]any{
			"name":       commonName,
			"cidr_ipv4":  "1.0.0.0/16",
			"enable_nat": false,
			"tier":       "Public",
		},
	})
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any), map[string]any{
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
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any)["task_definition"].(map[string]any), map[string]any{
		"env_file_name":        envKey,
		"repository_name":      strings.ToLower(fmt.Sprintf("%s-%s-%s", GithubProject.Organization, GithubProject.Repository, GithubProject.Branch)),
		"repository_image_tag": GithubProject.ImageTag,
	})
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["bucket_env"].(map[string]any), map[string]any{
		"file_key":  envKey,
		"file_path": "override.env",
	})

	return optionsProject, commonName
}

func RunTest(t *testing.T, options *terraform.Options, commonName string, ServiceTaskDesiredCount int64) {
	options = terraform.WithDefaultRetryableErrors(t, options)

	defer func() {
		if r := recover(); r != nil {
			// destroy all resources if panic
			terraform.Destroy(t, options)
		}
		terratest_structure.RunTestStage(t, "cleanup_scraper_backend", func() {
			terraform.Destroy(t, options)
		})
	}()

	terratest_structure.RunTestStage(t, "deploy_scraper_backend", func() {
		terraform.InitAndApply(t, options)
	})

	microservice.TestMicroservice(t, options, GithubProject, ServiceTaskDesiredCount)

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
			ExpectedBody:        util.Ptr(`"ok"`),
			MaxRetries:          3,
			SleepBetweenRetries: 30 * time.Second,
		},
		{
			Url:                 microservice.CheckUrlPrefix(dnsUrl + "/tags/wanted"),
			ExpectedStatus:      200,
			ExpectedBody:        util.Ptr(`[]`),
			MaxRetries:          3,
			SleepBetweenRetries: 30 * time.Second,
		},
	}

	terratest_structure.RunTestStage(t, "validate_rest_endpoints", func() {
		microservice.TestRestEndpoints(t, endpoints)
	})

}
