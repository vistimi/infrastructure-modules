package microservice_scraper_frontend_test

import (
	"fmt"
	"testing"

	"golang.org/x/exp/maps"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"

	testAwsProjectModule "github.com/dresspeng/infrastructure-modules/projects/test/aws/module"
	testAwsModule "github.com/dresspeng/infrastructure-modules/test/aws/module"
	"github.com/dresspeng/infrastructure-modules/test/util"
)

const (
	projectName = "scraper"
	serviceName = "frontend"

	listenerHttpPort             = 80
	listenerHttpProtocol         = "http"
	listenerHttpProtocolVersion  = "http1"
	listenerHttpsPort            = 443
	listenerHttpsProtocol        = "https"
	listenerHttpsProtocolVersion = "http1"
	targetPort                   = 3000
	targetProtocol               = "http"
	targetProtocolVersion        = "http1"

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

	Deployment = testAwsModule.DeploymentTest{
		MaxRetries: aws.Int(10),
		Endpoints: []testAwsModule.EndpointTest{
			{
				Path:           GithubProject.HealthCheckPath,
				ExpectedStatus: 200,
				ExpectedBody:   nil,
				MaxRetries:     aws.Int(3),
			},
		},
	}
)

func SetupOptionsRepository(t *testing.T) (*terraform.Options, string) {
	optionsMicroservice, nameSuffix := testAwsProjectModule.SetupOptionsMicroservice(t, projectName, serviceName)

	optionsProject := &terraform.Options{
		TerraformDir: MicroservicePath,
		Vars:         map[string]any{},
	}

	maps.Copy(optionsProject.Vars, optionsMicroservice.Vars)
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any), map[string]any{
		"iam": map[string]any{
			"scope":        "accounts",
			"requires_mfa": false,
		},
	})
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any), map[string]any{
		"traffics": []map[string]any{
			{
				"listener": map[string]any{
					// "port":     listenerHttpPort,
					"protocol": listenerHttpProtocol,
					// "protocol_version": listenerHttpProtocolVersion,
				},
				"target": map[string]any{
					"port":     targetPort,
					"protocol": targetProtocol,
					// "protocol_version":  targetProtocolVersion,
					"health_check_path": GithubProject.HealthCheckPath,
				},
			},
		},
	})
	envKey := fmt.Sprintf("%s.env", GithubProject.Branch)
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any)["task_definition"].(map[string]any), map[string]any{
		"docker": map[string]any{
			"registry": map[string]any{
				"ecr": map[string]any{
					"privacy": "private",
				},
			},
			"repository": map[string]any{
				"name": util.Format(GithubProject.Repository, GithubProject.Branch),
			},
			"image": map[string]any{
				"tag": GithubProject.ImageTag,
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

	return optionsProject, nameSuffix
}
