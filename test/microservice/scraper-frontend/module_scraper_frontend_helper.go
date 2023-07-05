package scraper_frontend_test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"golang.org/x/exp/maps"

	terratest_shell "github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"

	"github.com/KookaS/infrastructure-modules/test/module"
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

	MicroservicePath = "../../../module/aws/microservice/scraper-frontend"
)

var (
	GithubProject = module.GithubProjectInformation{
		Organization:    "KookaS",
		Repository:      "scraper-frontend",
		Branch:          "master", // TODO: make it flexible for testing other branches
		HealthCheckPath: "/healthz",
		ImageTag:        "latest",
	}

	Endpoints = []module.EndpointTest{
		{
			Path:                GithubProject.HealthCheckPath,
			ExpectedStatus:      200,
			ExpectedBody:        nil,
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

	optionsProject := &terraform.Options{
		TerraformDir: MicroservicePath,
		Vars:         map[string]any{},
	}

	maps.Copy(optionsProject.Vars, optionsMicroservice.Vars)
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any), map[string]any{
		"vpc": map[string]any{
			"name":       commonName,
			"cidr_ipv4":  "2.0.0.0/16",
			"enable_nat": false,
			"tier":       "Public",
		},
	})
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any), map[string]any{
		"traffic": map[string]any{
			"listeners": []map[string]any{
				{
					"port":             listenerPort,
					"protocol":         listenerProtocol,
					"protocol_version": listenerProtocolVersion,
				},
			},
			"targets": []map[string]any{
				{
					"port":               targetPort,
					"protocol":           targetProtocol,
					"protocol_version":   targetProtocolVersion,
					"health_check_path":         GithubProject.HealthCheckPath,
				},
			},		
		},

		listeners = list(objects({
			port             = number
			protocol         = string
			protocol_version = string
		  }))
		  targets = list(objects({
			port             = number
			protocol         = string
			protocol_version = string
		  }))
	})
	envKey := fmt.Sprintf("%s.env", GithubProject.Branch)
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any)["task_definition"].(map[string]any), map[string]any{
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
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["bucket_env"].(map[string]any), map[string]any{
		"file_key":  envKey,
		"file_path": "override.env",
	})

	return optionsProject, commonName
}
