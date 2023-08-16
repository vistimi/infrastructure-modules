package module

import (
	"crypto/tls"
	"fmt"
	"testing"
	"time"

	"github.com/dresspeng/infrastructure-modules/test/util"
	terratest_http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	terratestLogger "github.com/gruntwork-io/terratest/modules/logger"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

var (
	AccountName   = util.GetEnvVariable("AWS_PROFILE_NAME")
	AccountId     = util.GetEnvVariable("AWS_ACCOUNT_ID")
	AccountRegion = util.GetEnvVariable("AWS_REGION_NAME")
	DomainName    = fmt.Sprintf("%s.%s", util.GetEnvVariable("DOMAIN_NAME"), util.GetEnvVariable("DOMAIN_SUFFIX"))
)

const (
	// https://docs.aws.amazon.com/AmazonECS/latest/developerguide/memory-management.html#ecs-reserved-memory
	ECSReservedMemory = 100
)

type EC2Instance struct {
	Name          string
	Cpu           int
	Gpu           *int
	Memory        int
	MemoryAllowed int
	Architecture  string
}

var (
	// for amazon 2023 at least
	T3Small = EC2Instance{
		Name:          "t3.small",
		Cpu:           2048,
		Memory:        2048,
		MemoryAllowed: 1801, // TODO: double check under infra of cluster + ECSReservedMemory
		Architecture:  "x86_64",
	}
	T3Medium = EC2Instance{
		Name:          "t3.medium",
		Cpu:           2048,
		Memory:        4096,
		MemoryAllowed: 3828,
		Architecture:  "x86_64",
	}
	G4dnXlarge = EC2Instance{
		Name:          "g4dn.xlarge",
		Cpu:           4096,
		Gpu:           util.Ptr(1),
		Memory:        16384,
		MemoryAllowed: 15731,
		Architecture:  "gpu",
	}
)

type GithubProjectInformation struct {
	Organization string
	Repository   string
	Branch       string
	// WorkflowFilename string
	// WorkflowName     string
	HealthCheckPath string
	ImageTag        string
}

type EndpointTest struct {
	Path                string
	ExpectedStatus      int
	ExpectedBody        *string
	MaxRetries          *int
	SleepBetweenRetries *time.Duration
}

type DeploymentTest struct {
	MaxRetries          *int
	SleepBetweenRetries *time.Duration
	Endpoints           []EndpointTest
}

type LogTest struct {
	Group  string
	Stream string
}

type TrafficPoint struct {
	Port     *int
	Protocol string
}

type Traffic struct {
	Listener TrafficPoint
	Target   TrafficPoint
	Base     *bool
}

func ValidateMicroservice(t *testing.T, name string, microservicePath string, deployment DeploymentTest, traffics []Traffic, modulePath string) {
	terratestStructure.RunTestStage(t, "validate_microservice", func() {
		serviceCount := int64(1)
		serviceName := util.Format("-", name, "service")
		ValidateEcs(t, AccountRegion, name, serviceName, serviceCount, deployment)

		for _, traffic := range traffics {
			if traffic.Listener.Protocol == "http" {
				port := util.Value(traffic.Listener.Port, 80)
				// test Load Balancer HTTP
				elb := ExtractFromState(t, microservicePath, util.Format(".", modulePath, "ecs.elb"))
				if elb != nil {
					elbDnsUrl := elb.(map[string]any)["lb_dns_name"].(string)
					elbDnsUrl = fmt.Sprintf("http://%s:%d", elbDnsUrl, port)
					fmt.Printf("\n\nLoad Balancer DNS = %s\n\n", elbDnsUrl)

					// add dns to endpoints
					endpointsLoadBalancer := []EndpointTest{}
					for _, endpoint := range deployment.Endpoints {
						endpointsLoadBalancer = append(endpointsLoadBalancer, EndpointTest{
							Path:                elbDnsUrl + endpoint.Path,
							ExpectedStatus:      endpoint.ExpectedStatus,
							ExpectedBody:        endpoint.ExpectedBody,
							MaxRetries:          endpoint.MaxRetries,
							SleepBetweenRetries: endpoint.SleepBetweenRetries,
						})
					}

					terratestStructure.RunTestStage(t, "validate_rest_endpoints_load_balancer", func() {
						TestRestEndpoints(t, endpointsLoadBalancer)
					})
				}

				// test Route53
				route53 := ExtractFromState(t, microservicePath, "route53")
				if route53 != nil {
					zoneName := elb.(map[string]any)["zone"].(map[string]any)["name"].(string)
					recordSubdomainName := elb.(map[string]any)["record"].(map[string]any)["subdomain_name"].(string)
					route53DnsUrl := fmt.Sprintf("%s.%s:%d", recordSubdomainName, zoneName, port)
					fmt.Printf("\n\nRoute53 DNS = %s\n\n", route53DnsUrl)

					// add dns to endpoints
					endpointsRoute53 := []EndpointTest{}
					for _, endpoint := range deployment.Endpoints {
						endpointsRoute53 = append(endpointsRoute53, EndpointTest{
							Path:                route53DnsUrl + endpoint.Path,
							ExpectedStatus:      endpoint.ExpectedStatus,
							ExpectedBody:        endpoint.ExpectedBody,
							MaxRetries:          endpoint.MaxRetries,
							SleepBetweenRetries: endpoint.SleepBetweenRetries,
						})
					}

					terratestStructure.RunTestStage(t, "validate_rest_endpoints_route53", func() {
						TestRestEndpoints(t, endpointsRoute53)
					})
				}

			} else if traffic.Listener.Protocol == "https" {
				// port := util.Value(traffic.Listener.Port, 443)
				// TODO: add HTTPS
			}
		}
	})
}

func TestRestEndpoints(t *testing.T, endpoints []EndpointTest) {
	sleep := time.Second * 30
	terratestLogger.Log(t, fmt.Sprintf("Sleeping before testing endpoints %s...", sleep))
	time.Sleep(sleep)

	tlsConfig := tls.Config{}
	for _, endpoint := range endpoints {
		options := terratest_http_helper.HttpGetOptions{Url: endpoint.Path, TlsConfig: &tlsConfig, Timeout: 10}
		expectedBody := ""
		if endpoint.ExpectedBody != nil {
			expectedBody = *endpoint.ExpectedBody
		}
		maxRetries := 5
		if endpoint.MaxRetries != nil {
			maxRetries = *endpoint.MaxRetries
		}
		sleepBetweenRetries := 30 * time.Second
		if endpoint.SleepBetweenRetries != nil {
			sleepBetweenRetries = *endpoint.SleepBetweenRetries
		}
		for i := 0; i <= maxRetries; i++ {
			gotStatus, gotBody := terratest_http_helper.HttpGetWithOptions(t, options)
			terratestLogger.Log(t, fmt.Sprintf(`
			got status:: %d
			expected status:: %d
			`, gotStatus, endpoint.ExpectedStatus))
			if endpoint.ExpectedBody != nil {
				terratestLogger.Log(t, fmt.Sprintf(`
			got body:: %s
			expected body:: %s
			`, gotBody, expectedBody))
			}
			if gotStatus == endpoint.ExpectedStatus && (endpoint.ExpectedBody == nil || (endpoint.ExpectedBody != nil && gotBody == expectedBody)) {
				terratestLogger.Log(t, `'HTTP GET to URL %s' successful`, endpoint.Path)
				return
			}
			if i == maxRetries {
				t.Fatalf(`'HTTP GET to URL %s' unsuccessful after %d retries`, endpoint.Path, maxRetries)
			}
			terratestLogger.Log(t, fmt.Sprintf("Sleeping %s...", sleepBetweenRetries))
			time.Sleep(sleepBetweenRetries)
		}
	}
}
