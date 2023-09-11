package microservice_test

import (
	"fmt"
	"testing"

	"golang.org/x/exp/maps"

	"github.com/aws/aws-sdk-go/aws"
	testAwsProjectModule "github.com/dresspeng/infrastructure-modules/projects/test/aws/module"
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

	MicroserviceInformation = testAwsModule.MicroserviceInformation{
		Branch:          "trunk", // TODO: make it flexible for testing other branches
		HealthCheckPath: "/",
		Docker: testAwsModule.Docker{
			Registry: &testAwsModule.Registry{
				Ecr: &testAwsModule.Ecr{
					Privacy:    "private",
					AccountId:  util.Ptr("763104351884"),
					RegionName: util.Ptr("us-east-1"),
				},
			},
			Repository: testAwsModule.Repository{
				Name: "mxnet-inference",
			},
			Image: &testAwsModule.Image{
				// "1.8.1-cpu-py36-ubuntu18.04-v1.7",
				Tag: "1.6.0-cpu-py36-ubuntu16.04",
			},
		},
	}
	// "registry": map[string]any{
	// 	"name": "awsdeeplearningteam",
	// },
	// "repository": map[string]any{
	// 	"name": "multi-model-server",
	// },
	// "image": map[string]any{
	// 	"tag": "latest",
	// },

	Traffics = []testAwsModule.Traffic{
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

func SetupVars(t *testing.T) (vars map[string]any) {
	return map[string]any{}
}

// https://docs.aws.amazon.com/elastic-inference/latest/developerguide/ei-dlc-ecs-pytorch.html
// https://docs.aws.amazon.com/deep-learning-containers/latest/devguide/deep-learning-containers-ecs-tutorials-training.html
func Test_Unit_Microservice_Rest_EC2_Httpd(t *testing.T) {
	// t.Parallel()
	namePrefix, nameSuffix, tags, traffics, docker, bucketEnv := testAwsProjectModule.SetupMicroservice(t, MicroserviceInformation, Traffics)
	vars := SetupVars(t)
	serviceNameSuffix := "unique"

	options := util.Ptr(terraform.Options{
		TerraformDir: MicroservicePath,
		Vars: map[string]interface{}{
			"name_prefix": namePrefix,
			"name_suffix": nameSuffix,

			"vpc": map[string]any{
				"id":   util.GetEnvVariable("VPC_ID"),
				"tier": "public",
			},

			"microservice": map[string]any{
				"container": map[string]any{
					"group": map[string]any{
						"name": serviceNameSuffix,
						"deployment": map[string]any{
							"min_size":     1,
							"max_size":     1,
							"desired_size": 1,

							"container": map[string]any{
								"name":               "unique",
								"docker": docker,
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
							},
						},

						"ec2": map[string]any{
							"key_name":       nil,
							"instance_types": []string{"t3.small"},
							"os":             "linux",
							"os_version":     "2023",

							"capacities": []map[string]any{
								{
									"type":   "ON_DEMAND",
									"base":   nil, // no preferred instance amount
									"weight": 50,  // 50% chance
								},
							},
						},
					},

					"traffics": traffics,
					"ecs":      map[string]any{},
				},
				"iam": map[string]any{
					"scope":        "accounts",
					"requires_mfa": false,
				},
				"bucket_env": bucketEnv,
			},

			"tags": tags,
		},
	})
	maps.Copy(options.Vars, vars)

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
		terraform.Init(t, options)
		terraform.Plan(t, options)
		terraform.Apply(t, options)
	})
	terratestStructure.RunTestStage(t, "validate", func() {
		// TODO: test that /etc/ecs/ecs.config is not empty, requires key_name coming from terratest maybe
		name := util.Format("-", namePrefix, projectName, serviceName, nameSuffix)
		serviceName := util.Format("-", name, serviceNameSuffix)
		testAwsModule.ValidateMicroservice(t, name, Deployment, serviceName)
		testAwsModule.ValidateRestEndpoints(t, MicroservicePath, Deployment, Traffics, name, "")
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
