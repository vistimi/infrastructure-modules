package scraper_frontend_test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"golang.org/x/exp/maps"

	"github.com/gruntwork-io/terratest/modules/terraform"

	"github.com/KookaS/infrastructure-modules/test/module"
	"github.com/KookaS/infrastructure-modules/test/util"
)

const (
	projectName = "scraper"
	serviceName = "frontend"

	listenerHttpPort             = 80
	listenerHttpProtocol         = "http"
	listenerHttpProtocolVersion  = "http"
	listenerHttpsPort            = 443
	listenerHttpsProtocol        = "https"
	listenerHttpsProtocolVersion = "http"
	targetPort                   = 3000
	targetProtocol               = "http"
	targetProtocolVersion        = "http"

	MicroservicePath = "../../../module/aws/microservice/scraper-frontend"
)

var (
	GithubProject = module.GithubProjectInformation{
		Organization:    "KookaS",
		Repository:      "scraper-frontend",
		Branch:          "trunk", // TODO: make it flexible for testing other branches
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
	optionsMicroservice, commonName := module.SetupOptionsMicroservice(t, projectName, serviceName)

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
		"env_file_name": envKey,
		"repository": map[string]any{
			"privacy":    "private",
			"name":       strings.ToLower(fmt.Sprintf("%s-%s", GithubProject.Repository, GithubProject.Branch)),
			"image_tag":  GithubProject.ImageTag,
			"account_id": util.GetEnvVariable("REPOSITORIES_AWS_ACCOUNT_ID"),
			"region":     util.GetEnvVariable("REPOSITORIES_AWS_REGION_NAME"),
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
