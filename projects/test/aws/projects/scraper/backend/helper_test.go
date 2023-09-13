package microservice_scraper_backend_test

import (
	"path/filepath"
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/dresspeng/infrastructure-modules/test/util"

	testAwsModule "github.com/dresspeng/infrastructure-modules/test/aws/module"
)

const (
	projectName = "sp"
	serviceName = "be"

	Rootpath         = "../../../../.."
	MicroservicePath = Rootpath + "/module/aws/projects/scraper/backend"
)

var (
	MicroserviceInformation = testAwsModule.MicroserviceInformation{
		Branch:          "trunk", // TODO: make it flexible for testing other branches
		HealthCheckPath: "/healthz",
		Docker: testAwsModule.Docker{
			Registry: &testAwsModule.Registry{
				Ecr: &testAwsModule.Ecr{
					Privacy: "private",
				},
			},
			Repository: testAwsModule.Repository{
				Name: "scraper-backend-trunk", // TODO: make it flexible for testing other branches
			},
			Image: &testAwsModule.Image{
				Tag: "latest",
			},
		},
	}

	Traffics = []testAwsModule.Traffic{
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
				Path:           MicroserviceInformation.HealthCheckPath,
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

func SetupVars(t *testing.T) (vars map[string]any) {

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
	return vars
}
