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
	serviceName = "fe"

	Rootpath         = "../../../../.."
	MicroservicePath = Rootpath + "/module/aws/projects/scraper/frontend"
)

var (
	GithubProject = testAwsModule.GithubProjectInformation{
		Organization:    "dresspeng",
		Repository:      "scraper-frontend",
		Branch:          "trunk", // TODO: make it flexible for testing other branches
		HealthCheckPath: "/healthz",
		ImageTag:        "latest",
	}

	Traffic = []testAwsModule.Traffic{
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(80),
				Protocol: "http",
			},
			Target: testAwsModule.TrafficPoint{
				Port:     util.Ptr(3000),
				Protocol: "http",
			},
		},
		// {
		// 	Listener: testAwsModule.TrafficPoint{
		// 		Port:     util.Ptr(443),
		// 		Protocol: "https",
		// 	},
		// 	Target: testAwsModule.TrafficPoint{
		// 		Port:     util.Ptr(3000),
		// 		Protocol: "hTargetttps",
		// 	},
		// },
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

func SetupOptionsRepository(t *testing.T) (*terraform.Options, string, string) {
	optionsMicroservice, namePrefix, nameSuffix := testAwsProjectModule.SetupOptionsMicroserviceWrapper(t, projectName, serviceName)

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
	traffics := []map[string]any{}
	for _, traffic := range Traffic {
		traffics = append(traffics, map[string]any{
			"listener": map[string]any{
				"port":     util.Value(traffic.Listener.Port),
				"protocol": traffic.Listener.Protocol,
			},
			"target": map[string]any{
				"port":              util.Value(traffic.Target.Port),
				"protocol":          traffic.Target.Protocol,
				"health_check_path": GithubProject.HealthCheckPath,
			},
			"base": util.Value(traffic.Base),
		})
	}
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["ecs"].(map[string]any), map[string]any{
		"traffics": traffics,
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
				"name": util.Format("-", GithubProject.Repository, GithubProject.Branch),
			},
			"image": map[string]any{
				"tag": GithubProject.ImageTag,
			},
		},
		"readonly_root_filesystem": false,
	})
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["bucket_env"].(map[string]any), map[string]any{
		"file_key":  envKey,
		"file_path": "override.env",
	})

	return optionsProject, namePrefix, nameSuffix
}
