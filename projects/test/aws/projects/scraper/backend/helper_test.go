package microservice_scraper_backend_test

import (
	"fmt"
	"path/filepath"
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/dresspeng/infrastructure-modules/test/util"

	terratestShell "github.com/gruntwork-io/terratest/modules/shell"

	testAwsProjectModule "github.com/dresspeng/infrastructure-modules/projects/test/aws/module"
	testAwsModule "github.com/dresspeng/infrastructure-modules/test/aws/module"
)

const (
	projectName = "scraper"
	serviceName = "be"

	Rootpath         = "../../../../.."
	MicroservicePath = Rootpath + "/module/aws/projects/scraper/backend"
)

var (
	GithubProject = testAwsModule.GithubProjectInformation{
		Organization:    "dresspeng",
		Repository:      "scraper-backend",
		Branch:          "trunk", // TODO: make it flexible for testing other branches
		HealthCheckPath: "/healthz",
		ImageTag:        "latest",
	}

	Traffic = []testAwsModule.Traffic{
		{
			Listener: testAwsModule.TrafficPoint{
				Protocol: "http",
			},
			Target: testAwsModule.TrafficPoint{
				Port:     util.Ptr(8080),
				Protocol: "http",
			},
		},
		// {
		// 	Listener: testAwsModule.TrafficPoint{
		// 		Port:     util.Ptr(443),
		// 		Protocol: "https",
		// 	},
		// 	Target: testAwsModule.TrafficPoint{
		// 		Port:     util.Ptr(8080),
		// 		Protocol: "https",
		// 	},
		// },
	}

	Deployment = testAwsModule.DeploymentTest{
		MaxRetries: aws.Int(10),
		Endpoints: []testAwsModule.EndpointTest{
			{
				Path:           GithubProject.HealthCheckPath,
				ExpectedStatus: 200,
				ExpectedBody:   util.Ptr(`"ok"`),
				MaxRetries:     aws.Int(3),
			},
			{
				Path:           "/tags/wanted",
				ExpectedStatus: 200,
				ExpectedBody:   util.Ptr(`[]`),
				MaxRetries:     aws.Int(3),
			},
		},
	}
)

func SetupOptionsRepository(t *testing.T) (vars map[string]any, traffics []map[string]any, docker map[string]any, bucketEnv map[string]any) {
	_, nameSuffix, _ := testAwsProjectModule.SetupOptionsMicroserviceWrapper(t, projectName, serviceName)

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

	vars = map[string]any{
		"dynamodb_tables": dynamodb_tables,
		"bucket_picture": map[string]any{
			"name":          bucket_picture_name,
			"force_destroy": true,
			"versioning":    false,
		},
	}

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

	docker = map[string]any{
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
	}

	bucketEnv = map[string]any{
		"force_destroy": true,
		"versioning":    false,
		"file_key":      fmt.Sprintf("%s.env", GithubProject.Branch),
		"file_path":     "override.env",
	}

	return vars, traffics, docker, bucketEnv
}
