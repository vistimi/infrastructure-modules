package scraper_frontend_test

import (
	"fmt"
	"testing"

	"github.com/KookaS/infrastructure-modules/test/microservice"
	"golang.org/x/exp/maps"
	// terratest_aws "github.com/gruntwork-io/terratest/module/aws"
	// terratest_shell "github.com/gruntwork-io/terratest/module/shell"
)

func Test_Unit_ScraperFrontend_LB_EC2(t *testing.T) {
	t.Parallel()
	optionsProject, commonName := SetupOptionsProject(t)

	// https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html#enable_task_iam_roles
	// ECS_ENABLE_TASK_IAM_ROLE=true // Uses IAM roles for tasks for containers with the bridge and default network modes
	// ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true // Uses IAM roles for tasks for containers with the host network mode

	userDataOnDemand := fmt.Sprintf(`#!/bin/bash\ncat <<'EOF' >> /etc/ecs/ecs.config\nECS_CLUSTER=%s\nECS_LOGLEVEL=debug\n%s\nECS_RESERVED_MEMORY=%d\nEOF`, commonName, "ECS_ENABLE_TASK_IAM_ROLE=true", microservice.ECSReservedMemory)

	userDataSpot := fmt.Sprintf(`#!/bin/bash\ncat <<'EOF' >> /etc/ecs/ecs.config\nECS_CLUSTER=%s\nECS_LOGLEVEL=debug\n%s\nECS_RESERVED_MEMORY=%d\nECS_ENABLE_SPOT_INSTANCE_DRAINING=true\nEOF`, commonName, "ECS_ENABLE_TASK_IAM_ROLE=true", microservice.ECSReservedMemory)

	instance := microservice.T3Small
	keySpot := "spot"
	keyOnDemand := "on-demand"
	maps.Copy(optionsProject.Vars["ecs"].(map[string]any), map[string]any{
		"capacity_provider": map[string]map[string]any{
			keySpot: {
				"base":           nil, // no preferred instance amount
				"weight_percent": 50,  // 50% chance
			},
			keyOnDemand: {
				"base":           nil, // no preferred instance amount
				"weight_percent": 50,  // 50% chance
			},
		},
		"ec2": map[string]map[string]any{
			keySpot: {
				"user_data":            userDataSpot,
				"ami_ssm_architecture": "amazon-linux-2023",
				"instance_type":        instance.Name,
				"key_name":             nil,
				"use_spot":             true,
				"asg": map[string]any{
					"min_size":     0,
					"desired_size": 0, // TODO: set me to 1
					"max_size":     0, // TODO: set me to 1
					"instance_refresh": map[string]any{
						"strategy": "Rolling",
						"preferences": map[string]any{
							"checkpoint_delay":       600,
							"checkpoint_percentages": []int{35, 70, 100},
							"instance_warmup":        300,
							"min_healthy_percentage": 80,
						},
						"triggers": []string{"tag"},
					},
				},
				"capacity_provider": map[string]any{
					"target_capacity_cpu_percent": 70,
					"maximum_scaling_step_size":   1,
					"minimum_scaling_step_size":   1,
				},
			},
			keyOnDemand: {
				"user_data":            userDataOnDemand,
				"ami_ssm_architecture": "amazon-linux-2023",
				"instance_type":        instance.Name,
				"key_name":             nil,
				"use_spot":             false,
				"asg": map[string]any{
					"min_size":     0,
					"desired_size": 1,
					"max_size":     1,
					"instance_refresh": map[string]any{
						"strategy": "Rolling",
						"preferences": map[string]any{
							"checkpoint_delay":       600,
							"checkpoint_percentages": []int{35, 70, 100},
							"instance_warmup":        300,
							"min_healthy_percentage": 80,
						},
						"triggers": []string{"tag"},
					},
				},
				"capacity_provider": map[string]any{
					"target_capacity_cpu_percent": 70,
					"maximum_scaling_step_size":   1,
					"minimum_scaling_step_size":   1,
				},
			},
		},

		"service": map[string]any{
			"use_fargate":                        false,
			"task_desired_count":                 microservice.ServiceTaskDesiredCount,
			"deployment_minimum_healthy_percent": 66, // % tasks running required
			"deployment_circuit_breaker": map[string]any{
				"enable":   true,  // service deployment fail if no steady state
				"rollback": false, // rollback in case of failure
			},
		},
	})
	maps.Copy(optionsProject.Vars["ecs"].(map[string]any)["task_definition"].(map[string]any), map[string]any{
		"cpu":                instance.Cpu,                                            // supported CPU values are between 128 CPU units (0.125 vCPUs) and 10240 CPU units (10 vCPUs)
		"memory":             instance.MemoryAllowed - microservice.ECSReservedMemory, // the limit is dependent upon the amount of available memory on the underlying Amazon EC2 instance you use
		"memory_reservation": instance.MemoryAllowed - microservice.ECSReservedMemory, // memory_reservation <= memory
	})

	RunTest(t, optionsProject, commonName)

	// service := terratest_aws.GetEcsService(t, microservice.AccountRegion, commonName, commonName)
	// bashCode := fmt.Sprintf(`aws elbv2 describe-target-health --target-group-arn %s --query 'TargetHealthDescriptions[].TargetHealth.State'`, *service.LoadBalancers[0].TargetGroupArn)
	// command := terratest_shell.Command{
	// 	Command: "bash",
	// 	Args:    []string{"-c", bashCode},
	// }
	// targetHealthStates := strings.Fields(terratest_shell.RunCommandAndGetOutput(t, command))
	// for _, status := range targetHealthStates {
	// 	if status == "unhealthy" {
	// 		t.Fatal("At least one target is unhealthy")
	// 		return
	// 	}
	// }
}
