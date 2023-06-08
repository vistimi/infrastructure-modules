package scraper_frontend_test

import (
	"fmt"
	"testing"
	"time"

	"golang.org/x/exp/maps"

	"github.com/KookaS/infrastructure-modules/modules/services/microservice"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratest_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	projectName = "scraper"
	serviceName = "frontend"

	listenerPort     = 80
	listenerProtocol = "HTTP"
	targetPort       = 3000
	targetProtocol   = "HTTP"

	backend_dns = "dns_adress_test"
)

var (
	GithubProject = microservice.GithubProjectInformation{
		Organization:     "KookaS",
		Repository:       "scraper-frontend",
		Branch:           "master",
		WorkflowFilename: "cicd.yml",
		WorkflowName:     "CI/CD",
		HealthCheckPath:  "/healthz",
	}
)

func SetupOptionsProject(t *testing.T) (*terraform.Options, string) {

	optionsMicroservice, commonName := microservice.SetupOptionsMicroservice(t, projectName, serviceName)

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

func RunTest(t *testing.T, options *terraform.Options, commonName string) {
	options = terraform.WithDefaultRetryableErrors(t, options)

	defer func() {
		if r := recover(); r != nil {
			// destroy all resources if panic
			terraform.Destroy(t, options)
		}
		terratest_structure.RunTestStage(t, "cleanup_scraper_backend", func() {
			terraform.Destroy(t, options)
		})
	}()

	terratest_structure.RunTestStage(t, "deploy_scraper_frontend", func() {
		// create
		terraform.InitAndApply(t, options)

		// run pipeline
		bashCode := fmt.Sprintf(`
			gh workflow run %s --repo %s/%s --ref %s \
			-f aws-account-name=%s \
			-f common-name=%s \
			-f task-desired-count=%d \
			-f backend-dns=%s \
			|| exit 1
		`,
			GithubProject.WorkflowFilename,
			GithubProject.Organization,
			GithubProject.Repository,
			GithubProject.Branch,
			microservice.AccountName,
			commonName,
			microservice.ServiceTaskDesiredCountFinal,
			backend_dns,
		)
		microservice.RunGithubWorkflow(t, GithubProject, bashCode)
	})

	microservice.TestMicroservice(t, options, GithubProject)

	dnsUrl := terraform.Output(t, options, "alb_dns_name")
	fmt.Printf("\n\nDNS = %s\n\n", terraform.Output(t, options, "alb_dns_name"))
	endpoints := []microservice.EndpointTest{
		{
			Url:                 microservice.CheckUrlPrefix(dnsUrl + GithubProject.HealthCheckPath),
			ExpectedStatus:      200,
			ExpectedBody:        nil,
			MaxRetries:          3,
			SleepBetweenRetries: 20 * time.Second,
		},
	}

	terratest_structure.RunTestStage(t, "validate_rest_endpoints", func() {
		microservice.TestRestEndpoints(t, endpoints)
	})
}
