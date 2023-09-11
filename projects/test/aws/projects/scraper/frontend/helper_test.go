package microservice_scraper_frontend_test

import (
	"testing"

	"github.com/aws/aws-sdk-go/aws"

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
				Name: "scraper-frontend-trunk", // TODO: make it flexible for testing other branches
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
	return map[string]any{}
}
