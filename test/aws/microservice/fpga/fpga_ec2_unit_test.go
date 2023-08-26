package microservice_cuda_test

import (
	"fmt"
	"math/rand"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	testAwsModule "github.com/dresspeng/infrastructure-modules/test/aws/module"
	"github.com/dresspeng/infrastructure-modules/test/util"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	projectName = "ms"
	serviceName = "fpga"

	Rootpath         = "../../../.."
	MicroservicePath = Rootpath + "/module/aws/container/microservice"
)

var (
	AccountName   = util.GetEnvVariable("AWS_PROFILE_NAME")
	AccountId     = util.GetEnvVariable("AWS_ACCOUNT_ID")
	AccountRegion = util.GetEnvVariable("AWS_REGION_NAME")
	DomainName    = fmt.Sprintf("%s.%s", util.GetEnvVariable("DOMAIN_NAME"), util.GetEnvVariable("DOMAIN_SUFFIX"))

	Traffic = []testAwsModule.Traffic{
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(80),
				Protocol: "tcp",
			},
			Target: testAwsModule.TrafficPoint{
				Port:     util.Ptr(8080),
				Protocol: "tcp",
			},
			Base: util.Ptr(true),
		},
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(8081),
				Protocol: "tcp",
			},
			Target: testAwsModule.TrafficPoint{
				Port:     util.Ptr(8081),
				Protocol: "tcp",
			},
		},
	}

	Deployment = testAwsModule.DeploymentTest{
		MaxRetries: aws.Int(10),
		Endpoints: []testAwsModule.EndpointTest{
			{
				Command:        util.Ptr("curl -O https://s3.amazonaws.com/model-server/inputs/kitten.jpg && curl -X POST <URL>/predictions/squeezenet -T kitten.jpg"),
				ExpectedStatus: 200,
				MaxRetries:     aws.Int(3),
			},
		},
	}
)

// https://docs.aws.amazon.com/deep-learning-containers/latest/devguide/deep-learning-containers-ecs-tutorials-inference.html
func Test_Unit_Microservice_Fpga_Inferentia_EC2_MXNet(t *testing.T) {
	t.Parallel()

	rand.Seed(time.Now().UnixNano())

	// global variables
	id := util.RandomID(4)
	name := util.Format("-", projectName, serviceName, util.GetEnvVariable("AWS_PROFILE_NAME"), id)
	tags := map[string]string{
		"TestID":  id,
		"Account": AccountName,
		"Region":  AccountRegion,
		"Project": projectName,
		"Service": serviceName,
	}

	instance := testAwsModule.Inf1Xlarge
	keyOnDemand := "on-demand"

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
				"health_check_path": "/",
			},
			"base": util.Value(traffic.Base),
		})
	}
	devices := []map[string]any{}
	for _, devicePath := range instance.DevicePaths {
		devices = append(devices, map[string]any{

			"containerPath": devicePath,
			"hostPath":      devicePath,
			"permissions": []string{
				"read",
				"write",
			},
		})
	}
	options := &terraform.Options{
		TerraformDir: MicroservicePath,
		Vars: map[string]any{
			"name": name,
			"tags": tags,

			"vpc": map[string]any{
				"id":   "vpc-013a411b59dd8a08e",
				"tier": "public",
			},

			"container": map[string]any{
				"traffics": traffics,
				"group": map[string]any{
					"deployment": map[string]any{
						"min_count":     1,
						"desired_count": 1,
						"max_count":     1,

						"cpu":    instance.Cpu,
						"memory": instance.MemoryAllowed,

						"containers": []map[string]any{
							{
								"cpu":                instance.Cpu,
								"memory_reservation": instance.MemoryAllowed,

								"entrypoint": []string{
									"/bin/bash",
									"-c",
								},
								// docker run --entrypoint /bin/bash -p 80:8080 -p 8081:8081 763104351884.dkr.ecr.us-east-1.amazonaws.com/mxnet-inference:1.6.0-cpu-py36-ubuntu16.04 -c 'multi-model-server --start --mms-config /home/model-server/config.properties --models squeezenet=https://s3.amazonaws.com/model-server/models/squeezenet_v1.1/squeezenet_v1.1.model; curl -O https://s3.amazonaws.com/model-server/inputs/kitten.jpg && curl -X POST http://0.0.0.0/predictions/squeezenet -T kitten.jpg'

								// docker run --entrypoint /bin/bash -p 80:8080 -p 8081:8081 763104351884.dkr.ecr.us-east-1.amazonaws.com/mxnet-inference:1.6.0-cpu-py36-ubuntu16.04 -c 'git clone https://github.com/awslabs/multi-model-server.git; cd multi-model-server; multi-model-server --start --mms-config /home/model-server/config.properties --model-store examples --models squeezenet_v1.1.mar; curl -X POST http://127.0.0.1:8080/predictions/squeezenet_v1.1 -T docs/images/kitten_small.jpg'

								// docker run --entrypoint /bin/bash -p 80:8080 -p 8081:8081 763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference:1.3.1-cpu-py36-ubuntu16.04 -c 'git clone https://github.com/pytorch/serve.git; cd serve; ls examples/image_classifier/densenet_161/; python -m pip install torch-model-archiver torchserve; wget https://download.pytorch.org/models/densenet161-8d451a50.pth; torch-model-archiver --model-name densenet161 --version 1.0 --model-file examples/image_classifier/densenet_161/model.py --serialized-file densenet161-8d451a50.pth --handler image_classifier --extra-files examples/image_classifier/index_to_name.json; mkdir model_store; mv densenet161.mar model_store/; torchserve --start --model-store model_store --models densenet161=densenet161.mar; curl http://127.0.0.1:8080/predictions/densenet161 -T examples/image_classifier/kitten.jpg'

								"command": []string{
									"cat /home/model-server/config.properties; mxnet-model-server --start --mms-config /home/model-server/config.properties --models squeezenet=https://s3.amazonaws.com/model-server/models/squeezenet_v1.1/squeezenet_v1.1.model; curl -O https://s3.amazonaws.com/model-server/inputs/kitten.jpg && curl -X POST http://127.0.0.1/predictions/squeezenet -T kitten.jpg",

									// "multi-model-server --start --models squeezenet=https://s3.amazonaws.com/model-server/model_archive_1.0/squeezenet_v1.1.mar",
								},
								// "health_check": map[string]any{
								// 	"command": []string{"CMD-SHELL", "curl -O https://s3.amazonaws.com/model-server/inputs/kitten.jpg && curl -X POST http://127.0.0.1/predictions/squeezenet -T kitten.jpg || exit 1"},
								// },
								"readonly_root_filesystem": false,

								"linux_parameters": map[string]any{
									"devices": devices,
									"capabilities": map[string]any{
										"add": []string{"IPC_LOCK"},
									},
								},

								// WARNING: requires permissions to that private external account ECR repository
								"docker": map[string]any{
									"registry": map[string]any{
										"ecr": map[string]any{
											"privacy":     "private",
											"account_id":  "763104351884",
											"region_name": "us-east-1",
										},
									},
									"repository": map[string]any{
										"name": "mxnet-inference",
									},
									"image": map[string]any{
										// "tag": "1.8.1-cpu-py36-ubuntu18.04-v1.7",
										"tag": "1.6.0-cpu-py36-ubuntu16.04",
									},
									// "registry": map[string]any{
									// 	"name": "awsdeeplearningteam",
									// },
									// "repository": map[string]any{
									// 	"name": "multi-model-server",
									// },
									// "image": map[string]any{
									// 	"tag": "latest",
									// },
								},
							},
						},
					},

					"ec2": map[string]map[string]any{
						keyOnDemand: {
							"os":           "linux",
							"os_version":   "2023",
							"architecture": instance.Architecture,
							"processor":    instance.Processor,

							"instance_type": instance.Name,
							"key_name":      nil,
							"use_spot":      false,
							"asg": map[string]any{
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
								"base":                        nil, // no preferred instance amount
								"weight":                      50,  // 50% chance
								"target_capacity_cpu_percent": 70,
							},
						},
					},
				},
			},

			"ecs": map[string]any{},

			"iam": map[string]any{
				"scope":        "accounts",
				"requires_mfa": false,
			},
		},
	}

	defer func() {
		if r := recover(); r != nil {
			// destroy all resources if panic
			terraform.Destroy(t, options)
		}
		terratestStructure.RunTestStage(t, "cleanup", func() {
			terraform.Destroy(t, options)
		})
	}()

	terratestStructure.RunTestStage(t, "deploy", func() {
		terraform.InitAndApply(t, options)
	})

	terratestStructure.RunTestStage(t, "validate", func() {
		// TODO: test that /etc/ecs/ecs.config is not empty, requires key_name coming from terratest maybe
		testAwsModule.ValidateMicroservice(t, name, Deployment)
		testAwsModule.ValidateRestEndpoints(t, MicroservicePath, Deployment, Traffic, name, "")
	})
}

// // MXNet
// vmargs=-XX:+UseContainerSupport -XX:InitialRAMPercentage=8.0 -XX:MaxRAMPercentage=10.0 -XX:-UseLargePages -XX:+UseG1GC -XX:+ExitOnOutOfMemoryError
// model_store=/opt/ml/model
// load_models=ALL
// inference_address=http://0.0.0.0:8080
// management_address=http://0.0.0.0:8081

//	// Pytorch: /home/model-server/config.properties
// vmargs=-Xmx128m -XX:-UseLargePages -XX:+UseG1GC -XX:MaxMetaspaceSize=32M -XX:MaxDirectMemorySize=10m -XX:+ExitOnOutOfMemoryError
// model_store=/opt/ml/model
// load_models=ALL
// inference_address=http://0.0.0.0:8080
// management_address=http://0.0.0.0:8081
// # management_address=unix:/tmp/management.sock
// # number_of_netty_threads=0
// # netty_client_threads=0
// # default_response_timeout=120
// # default_workers_per_model=0
// # job_queue_size=100
// # async_logging=false
// # number_of_gpu=1
// # cors_allowed_origin
// # cors_allowed_methods
// # cors_allowed_headers
// # keystore=src/test/resources/keystore.p12
// # keystore_pass=changeit
// # keystore_type=PKCS12
// # private_key_file=src/test/resources/key.pem
// # certificate_file=src/test/resources/certs.pem
// # max_response_size=6553500
// # max_request_size=6553500
// # blacklist_env_vars=
// # decode_input_request=false
// # enable_envvars_config=false
