package module_test

import (
	"fmt"
	"testing"
	"time"

	awsSDK "github.com/aws/aws-sdk-go/aws"
	"github.com/likexian/gokit/assert"

	terratest_aws "github.com/gruntwork-io/terratest/modules/aws"
	terratest_logger "github.com/gruntwork-io/terratest/modules/logger"
)

// https://github.com/gruntwork-io/terratest/blob/master/test/terraform_aws_ecs_example_test.go
func TestEcs(t *testing.T, accountRegion, clusterName, serviceName string, serviceCount, serviceTaskDesiredCount int64) {
	// cluster
	cluster := terratest_aws.GetEcsCluster(t, accountRegion, clusterName)
	if cluster == nil {
		t.Fatalf("no service")
	}
	assert.Equal(t, awsSDK.Int64Value(cluster.ActiveServicesCount), serviceCount, "amount of services do not match")

	// tasks in service
	service := terratest_aws.GetEcsService(t, accountRegion, clusterName, serviceName)
	if service == nil {
		t.Fatalf("no service")
	}
	assert.Equal(t, awsSDK.Int64Value(service.DesiredCount), serviceTaskDesiredCount, "amount of tasks in service do not match")

	taskDefinition := terratest_aws.GetEcsTaskDefinition(t, accountRegion, awsSDK.StringValue(service.TaskDefinition))
	if taskDefinition == nil {
		t.Fatalf("no task definition")
	}
	latestTaskDefinitionArn := taskDefinition.TaskDefinitionArn
	if latestTaskDefinitionArn == nil {
		t.Fatalf("no task definition arn")
	}
	fmt.Printf("\n\nlatestTaskDefinitionArn = %s\n\n", *latestTaskDefinitionArn)

	if len(service.Deployments) == 0 {
		t.Fatalf("no service deployment")
	}
	deployment := service.Deployments[0] // one deployment because no other service update, take the last one otherwise
	assert.Equal(t, awsSDK.Int64Value(deployment.DesiredCount), serviceTaskDesiredCount, "amount of desired tasks in service do not match")

	maxRetries := 5
	sleepBetweenRetries := time.Second * 30
	for i := 0; i <= maxRetries; i++ {
		deployment := terratest_aws.GetEcsService(t, accountRegion, clusterName, serviceName).Deployments[0]
		terratest_logger.Log(t, fmt.Sprintf(`
		tasks FAILURE:: %d
		tasks RUNNING:: %d
		tasks PENDING:: %d
		tasks DESIRED:: %d
		`, awsSDK.Int64Value(deployment.FailedTasks), awsSDK.Int64Value(deployment.RunningCount), awsSDK.Int64Value(deployment.PendingCount), serviceTaskDesiredCount))
		if awsSDK.Int64Value(deployment.RunningCount) == serviceTaskDesiredCount {
			terratest_logger.Log(t, `'Task deployment successful`)
			break
		}
		if i == maxRetries {
			t.Fatalf(`Task deployment unsuccessful after %d retries`, maxRetries)
		}
		terratest_logger.Log(t, fmt.Sprintf("Sleeping %s...", sleepBetweenRetries))
		time.Sleep(sleepBetweenRetries)
	}
}
