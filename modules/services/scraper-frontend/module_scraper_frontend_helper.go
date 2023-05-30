package scraper_frontend_test

import (
	"fmt"
	"testing"

	"golang.org/x/exp/maps"

	"github.com/gruntwork-io/terratest/modules/terraform"

	helper_test "github.com/KookaS/infrastructure-modules/modules/services/helper"
)

const (
	projectName = "scraper"
	serviceName = "frontend"

	listenerPort     = 80
	listenerProtocol = "HTTP"
	targetPort       = 3000
	targetProtocol   = "HTTP"
)

var (
	GithubProject = helper_test.GithubProjectInformation{
		Organization:     "KookaS",
		Repository:       "scraper-frontend",
		Branch:           "master",
		WorkflowFilename: "cicd.yml",
		WorkflowName:     "CI/CD",
		HealthCheckPath:  "/healthz",
	}
)

func SetupOptionsProject(t *testing.T) (*terraform.Options, string) {

	optionsMicroservice, commonName := helper_test.SetupOptionsMicroservice(t, projectName, serviceName)

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
