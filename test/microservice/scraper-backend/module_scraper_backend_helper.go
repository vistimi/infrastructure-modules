package scraper_backend_test

import (
	"fmt"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"golang.org/x/exp/maps"

	"github.com/KookaS/infrastructure-modules/test/util"

	terratest_shell "github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"

	"github.com/KookaS/infrastructure-modules/test/module"
)

const (
	projectName = "scraper"
	serviceName = "backend"

	listenerHttpPort             = 80
	listenerHttpProtocol         = "http"
	listenerHttpProtocolVersion  = "http"
	listenerHttpsPort            = 443
	listenerHttpsProtocol        = "https"
	listenerHttpsProtocolVersion = "http"
	targetPort                   = 8080
	targetProtocol               = "http"
	targetProtocolVersion        = "http"

	MicroservicePath = "../../../module/aws/microservice/scraper-backend"
)

var (
	GithubProject = module.GithubProjectInformation{
		Organization:    "KookaS",
		Repository:      "scraper-backend",
		Branch:          "master", // TODO: make it flexible for testing other branches
		HealthCheckPath: "/healthz",
		ImageTag:        "latest",
	}

	Endpoints = []module.EndpointTest{
		{
			Path:                GithubProject.HealthCheckPath,
			ExpectedStatus:      200,
			ExpectedBody:        util.Ptr(`"ok"`),
			MaxRetries:          3,
			SleepBetweenRetries: 30 * time.Second,
		},
		{
			Path:                "/tags/wanted",
			ExpectedStatus:      200,
			ExpectedBody:        util.Ptr(`[]`),
			MaxRetries:          3,
			SleepBetweenRetries: 30 * time.Second,
		},
	}
)

func SetupOptionsProject(t *testing.T) (*terraform.Options, string) {

	// setup terraform override variables
	bashCode := fmt.Sprintf(`cd %s; terragrunt init;`, MicroservicePath)
	command := terratest_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	terratest_shell.RunCommandAndGetOutput(t, command)

	optionsMicroservice, commonName := module.SetupOptionsMicroservice(t, projectName, serviceName)

	// override.env
	bashCode = fmt.Sprintf("echo COMMON_NAME=%s >> %s/override.env", commonName, MicroservicePath)
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
		TerraformDir: MicroservicePath,
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
			"name":      commonName,
			"cidr_ipv4": "100.0.0.0/16",
			"tier":      "public",
		},
		"iam": map[string]any{
			"scope": "microservices",
		},
	})
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any), map[string]any{
		"traffic": map[string]any{
			"listeners": []map[string]any{
				{
					"port":             listenerHttpPort,
					"protocol":         listenerHttpProtocol,
					"protocol_version": listenerHttpProtocolVersion,
				},
			},
			"target": map[string]any{
				"port":              targetPort,
				"protocol":          targetProtocol,
				"protocol_version":  targetProtocolVersion,
				"health_check_path": GithubProject.HealthCheckPath,
			},
		},
	})
	envKey := fmt.Sprintf("%s.env", GithubProject.Branch)
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any)["task_definition"].(map[string]any), map[string]any{
		"env_file_name":        envKey,
		"repository_privacy":   "public",
		"repository_alias":     "not-known-yet",
		"repository_name":      strings.ToLower(fmt.Sprintf("%s-%s-%s", GithubProject.Organization, GithubProject.Repository, GithubProject.Branch)),
		"repository_image_tag": GithubProject.ImageTag,
	})
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["bucket_env"].(map[string]any), map[string]any{
		"file_key":  envKey,
		"file_path": "override.env",
	})

	return optionsProject, commonName
}
