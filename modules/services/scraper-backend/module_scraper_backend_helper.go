package scraper_backend_test

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"
	"time"

	"golang.org/x/exp/maps"

	"github.com/KookaS/infrastructure-modules/modules/components/microservice"
	"github.com/KookaS/infrastructure-modules/util"

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
)

var (
	GithubProject = microservice.GithubProjectInformation{
		Organization:     "KookaS",
		Repository:       "scraper-backend",
		Branch:           "master",
		WorkflowFilename: "cicd.yml",
		WorkflowName:     "CI/CD",
		HealthCheckPath:  "/healthz",
	}
)

func SetupOptionsProject(t *testing.T) (*terraform.Options, string) {

	optionsMicroservice, commonName := microservice.SetupOptionsMicroservice(t, projectName, serviceName)

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
		TerraformDir: "",
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
	maps.Copy(optionsProject.Vars["ecs"].(map[string]any)["task_definition"].(map[string]any), map[string]any{
		"env_file_name": fmt.Sprintf("%s.env", GithubProject.Branch),
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
		terratest_structure.RunTestStage(t, "cleanup_scraper_backend", func() {
			terraform.Destroy(t, options)
		})
	}()

	terratest_structure.RunTestStage(t, "deploy_scraper_backend", func() {
		// create
		terraform.InitAndApply(t, options)

		// run pipeline
		bashCode := fmt.Sprintf(`
			gh workflow run %s --repo %s/%s --ref %s \
			-f aws-account-name=%s \
			-f common-name=%s \
			-f task-desired-count=%d \
			|| exit 1
		`,
			GithubProject.WorkflowFilename,
			GithubProject.Organization,
			GithubProject.Repository,
			GithubProject.Branch,
			microservice.AccountName,
			commonName,
			microservice.ServiceTaskDesiredCountFinal,
		)
		microservice.RunGithubWorkflow(t, GithubProject, bashCode)
	})

	microservice.TestMicroservice(t, options, GithubProject)

	// dnsUrl := terraform.Output(t, options, "alb_dns_name")
	jsonFile, err := os.Open("terraform.tfstate")
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
