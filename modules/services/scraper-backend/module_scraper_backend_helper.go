package scraper_backend_test

import (
	"fmt"
	"path/filepath"
	"testing"

	"golang.org/x/exp/maps"

	"github.com/gruntwork-io/terratest/modules/terraform"

	helper_test "github.com/KookaS/infrastructure-modules/modules/services/helper"
)

const (
	projectName = "scraper"
	serviceName = "backend"

	listenerPort     = 80
	listenerProtocol = "HTTP"
	targetPort       = 8080
	targetProtocol   = "HTTP"
)

var (
	GithubProject = helper_test.GithubProjectInformation{
		Organization: "KookaS",
		Repository:   "scraper-backend",
		// github_repository_id : "497233030",
		Branch:           "master",
		WorkflowFilename: "cicd.yml",
		WorkflowName:     "CI/CD",
		HealthCheckPath:  "/healthz",
	}
)

func SetupOptionsProject(t *testing.T) (*terraform.Options, string) {

	optionsMicroservice, commonName := helper_test.SetupOptionsMicroservice(t, projectName, serviceName)

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
			"traffic": map[string]any{
				"listener_port":     listenerPort,
				"listener_protocol": listenerProtocol,
				"target_port":       targetPort,
				"target_protocol":   targetProtocol,
				"health_check_path": GithubProject.HealthCheckPath,
			},
			"dynamodb_tables": dynamodb_tables,
			"bucket_picture": map[string]any{
				"name":          bucket_picture_name,
				"force_destroy": true,
				"versioning":    false,
			},
		},
	}

	maps.Copy(optionsProject.Vars, optionsMicroservice.Vars)
	maps.Copy(optionsProject.Vars["task_definition"].(map[string]any), map[string]any{
		"env_file_name": fmt.Sprintf("%s.env", GithubProject.Branch),
		"port_mapping": []map[string]any{
			{
				"name":          "container-port",
				"hostPort":      targetPort,
				"protocol":      "tcp",
				"containerPort": targetPort,
			},
		},
	})

	return optionsProject, commonName
}
