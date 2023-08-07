package microservice_scraper_backend_test

import (
	"fmt"
	"path/filepath"
	"testing"
	"time"

	"golang.org/x/exp/maps"

	"github.com/dresspeng/infrastructure-modules/test/util"

	terratestShell "github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"

	testAwsProjectModule "github.com/dresspeng/infrastructure-modules/projects/test/aws/module"
	testAwsModule "github.com/dresspeng/infrastructure-modules/test/aws/module"
)

const (
	projectName = "scraper"
	serviceName = "backend"

	listenerHttpPort             = 80
	listenerHttpProtocol         = "http"
	listenerHttpProtocolVersion  = "http1"
	listenerHttpsPort            = 443
	listenerHttpsProtocol        = "https"
	listenerHttpsProtocolVersion = "http1"
	targetPort                   = 8080
	targetProtocol               = "http"
	targetProtocolVersion        = "http1"

	Rootpath         = "../../../.."
	MicroservicePath = Rootpath + "/module/aws/microservice/scraper-backend"
)

var (
	GithubProject = testAwsModule.GithubProjectInformation{
		Organization:    "dresspeng",
		Repository:      "scraper-backend",
		Branch:          "trunk", // TODO: make it flexible for testing other branches
		HealthCheckPath: "/healthz",
		ImageTag:        "latest",
	}

	Endpoints = []testAwsModule.EndpointTest{
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

func SetupOptionsRepository(t *testing.T) (*terraform.Options, string) {
	optionsMicroservice, nameSuffix := testAwsProjectModule.SetupOptionsMicroservice(t, projectName, serviceName)

	// override.env
	bashCode := fmt.Sprintf("echo COMMON_NAME=%s >> %s/override.env", nameSuffix, MicroservicePath)
	command := terratestShell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	terratestShell.RunCommandAndGetOutput(t, command)

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
	bucket_picture_name := *bucket_picture_name_extension.Name

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
				"tag": "latest",
			},
		},
	})
	maps.Copy(optionsProject.Vars["microservice"].(map[string]any)["bucket_env"].(map[string]any), map[string]any{
		"file_key":  envKey,
		"file_path": "override.env",
	})

	return optionsProject, nameSuffix
}