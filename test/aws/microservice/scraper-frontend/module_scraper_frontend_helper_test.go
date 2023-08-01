package microservice_scraper_frontend_test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"golang.org/x/exp/maps"

	"github.com/gruntwork-io/terratest/modules/terraform"

	testAwsModule "github.com/dresspeng/infrastructure-modules/test/aws/module"
)

const (
	projectName = "scraper"
	serviceName = "frontend"

	Rootpath         = "../../../.."
	MicroservicePath = Rootpath + "/module/aws/microservice/scraper-frontend"
)

var (
	GithubProject = testAwsModule.GithubProjectInformation{
		Organization:    "dresspeng",
		Repository:      "scraper-frontend",
		Branch:          "trunk", // TODO: make it flexible for testing other branches
		HealthCheckPath: "/healthz",
		ImageTag:        "latest",
	}

	Endpoints = []testAwsModule.EndpointTest{
		{
			Path:                GithubProject.HealthCheckPath,
			ExpectedStatus:      200,
			ExpectedBody:        nil,
			MaxRetries:          3,
			SleepBetweenRetries: 30 * time.Second,
		},
	}
)

func SetupOptionsRepository(t *testing.T) (*terraform.Options, string) {
	optionsMicroservice, commonName := testAwsModule.SetupOptionsMicroservice(t, projectName, serviceName)

	optionsProject := &terraform.Options{
		TerraformDir: MicroservicePath,
		Vars:         map[string]any{},
	}

	maps.Copy(optionsProject.Vars, optionsMicroservice.Vars)
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any), map[string]any{
		"vpc": map[string]any{
			"name":      commonName,
			"cidr_ipv4": "101.0.0.0/16",
			"tier":      "public",
		},
		"iam": map[string]any{
			"scope":        "microservices",
			"requires_mfa": false,
		},
	})
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any), map[string]any{
		"traffics": []map[string]any{
			{
				"listener": map[string]any{
					"protocol": "http",
				},
				"target": map[string]any{
					"port":     8080,
					"protocol": "http",
				},
			},
		},
	})
	envKey := fmt.Sprintf("%s.env", GithubProject.Branch)
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any)["task_definition"].(map[string]any), map[string]any{
		"env_file_name": envKey,
		"docker": map[string]any{
			"registry": map[string]any{
				"ecr": map[string]any{
					"privacy": "private",
				},
			},
			"repository": map[string]any{
				"name": strings.ToLower(fmt.Sprintf("%s-%s", GithubProject.Repository, GithubProject.Branch)),
			},
		},
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
