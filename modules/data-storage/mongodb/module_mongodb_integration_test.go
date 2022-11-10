package test

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"go.mongodb.org/mongo-driver/mongo/readpref"

	test_shell "github.com/gruntwork-io/terratest/modules/shell"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

var (
	bucket_name_mongodb  = "scraper-test-mongodb"
	bucket_name_pictures = "scraper-test-pictures"
)

func TestTerraformMongodbUnitTest(t *testing.T) {
	t.Parallel()

	bashCode := fmt.Sprint(`terragrunt init;`)
	command := test_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	shellOutput := test_shell.RunCommandAndGetOutput(t, command)
	fmt.Printf("\nStart shell output: %s\n", shellOutput)

	id := uuid.New().String()[0:7]
	bastion := true
	account_name := os.Getenv("AWS_PROFILE")
	aws_region := os.Getenv("AWS_REGION")
	environment_name := fmt.Sprintf("scraper-mongodb-%s", id)
	common_name := strings.ToLower(fmt.Sprintf("%s-%s-%s", account_name, aws_region, environment_name))

	vpc_id := terraform.Output(t, &terraform.Options{TerraformDir: "../../vpc"}, "vpc_id")
	default_security_group_id := terraform.Output(t, &terraform.Options{TerraformDir: "../../vpc"}, "default_security_group_id")
	private_subnets := terraform.OutputList(t, &terraform.Options{TerraformDir: "../../vpc"}, "private_subnets")
	public_subnets := terraform.OutputList(t, &terraform.Options{TerraformDir: "../../vpc"}, "private_subnets")

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "",
		Vars: map[string]interface{}{
			"aws_region":             aws_region,
			"data_storage_name":      common_name,
			"private_subnets":        private_subnets,
			"public_subnets":         public_subnets,
			"vpc_security_group_ids": []string{default_security_group_id},
			"vpc_id":                 vpc_id,
			"common_tags": map[string]string{
				"Account":     account_name,
				"Region":      aws_region,
				"Environment": environment_name,
			},
			"ami_id":         "ami-09d3b3274b6c5d4aa",
			"instance_type":  "t2.micro",
			"user_data_path": "mongodb.sh",
			"user_data_args": map[string]string{
				"bucket_name_mount_helper": "global-mount-helper",
				"bucket_name_mongodb":      fmt.Sprintf("%s-mongodb", common_name),
				"bucket_name_pictures":     fmt.Sprintf("%s-pictures", common_name),
				"mongodb_version":          "6.0.1",
				"aws_region":               aws_region,
				"aws_profile":              account_name,
			},
			"bastion": bastion,
		},
		VarFiles: []string{"terraform_override.tfvars"},
		// BackendConfig: map[string]interface{}{
		// 	"bucket":         fmt.Sprintf("%s-%s-%s-terraform-state", account_name, aws_region, environment_name),
		// 	"key":            "global/s3/terraform.tfstate",
		// 	"region":         aws_region,
		// 	"dynamodb_table": fmt.Sprintf("%s-%s-%s-terraform-locks", account_name, aws_region, environment_name),
		// 	"encrypt":        true,
		// },

		RetryableTerraformErrors: map[string]string{
			"net/http: TLS handshake timeout": "Terraform bug",
		},
	})

	defer func() {
		if r := recover(); r != nil {
			// destroy all resources if panic
			terraform.Destroy(t, terraformOptions)
		}
		test_structure.RunTestStage(t, "cleanup_mongodb", func() {
			terraform.Destroy(t, terraformOptions)
		})
	}()

	test_structure.RunTestStage(t, "deploy_mongodb", func() {
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate_ssh", func() {
		publicInstanceIPBastion := terraform.OutputList(t, terraformOptions, "ec2_instance_bastion_public_ip")[0]
		privateInstanceIPMongodb := terraform.Output(t, terraformOptions, "ec2_instance_mongodb_private_ip")
		keyPair := ssh.KeyPair{
			PublicKey:  terraform.Output(t, terraformOptions, "public_key_openssh"),
			PrivateKey: terraform.Output(t, terraformOptions, "private_key_openssh"),
		}

		fmt.Println("KEYYYYYYYYYYY", keyPair)
		fmt.Println("IPPPPPPPP", publicInstanceIPBastion, privateInstanceIPMongodb)

		sshToPrivateHost(t, publicInstanceIPBastion, privateInstanceIPMongodb, &keyPair)
	})

	test_structure.RunTestStage(t, "validate_mongodb", func() {
		s3bucketMongodbArn := terraform.Output(t, terraformOptions, "s3_bucket_mongodb_arn")
		s3bucketpicturesArn := terraform.Output(t, terraformOptions, "s3_bucket_pictures_arn")
		assert.Equal(t, fmt.Sprintf("arn:aws:s3:::%s", bucket_name_mongodb), s3bucketMongodbArn)
		assert.Equal(t, fmt.Sprintf("arn:aws:s3:::%s", bucket_name_pictures), s3bucketpicturesArn)

		err := mongodbOperations()
		assert.Equal(t, nil, err)
	})
}

func mongodbOperations() error {
	uri := "mongodb://localhost:27017"
	// connect
	client, err := mongo.Connect(context.TODO(), options.Client().ApplyURI(uri))
	if err != nil {
		return err
	}
	// Ping the primary
	if err := client.Ping(context.TODO(), readpref.Primary()); err != nil {
		return err
	}
	// test operations
	collection := client.Database("test").Collection("test")
	document := bson.M{"testField": "testValue"}
	_, err = collection.InsertOne(context.TODO(), document)
	if err != nil {
		return err
	}
	var found struct{ testField string }
	err = collection.FindOne(context.TODO(), document).Decode(&found)
	if err != nil {
		return err
	}
	return nil
}

func sshToPrivateHost(t *testing.T, publicInstanceIP string, privateInstanceIP string, keyPair *ssh.KeyPair) {
	// We're going to try to SSH to the private instance using the public instance as a jump host. For both instances,
	// we are using the Key Pair we created earlier, and the user "ubuntu", as we know the Instances are running an
	// Ubuntu AMI that has such a user
	publicHost := ssh.Host{
		Hostname:    publicInstanceIP,
		SshKeyPair:  keyPair,
		SshUserName: "ec2-user",
	}
	privateHost := ssh.Host{
		Hostname:    privateInstanceIP,
		SshKeyPair:  keyPair,
		SshUserName: "ec2-user",
	}

	// It can take a minute or so for the Instance to boot up, so retry a few times
	maxRetries := 30
	timeBetweenRetries := 5 * time.Second
	description := fmt.Sprintf("SSH to private host %s via public host %s", privateInstanceIP, publicInstanceIP)

	// Run a simple echo command on the server
	expectedText := "Hello, World"
	command := fmt.Sprintf("echo -n '%s'", expectedText)

	// Verify that we can SSH to the Instance and run commands
	retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		actualText, err := ssh.CheckPrivateSshConnectionE(t, publicHost, privateHost, command)

		if err != nil {
			return "", err
		}

		if strings.TrimSpace(actualText) != expectedText {
			return "", fmt.Errorf("Expected SSH command to return '%s' but got '%s'", expectedText, actualText)
		}

		return "", nil
	})
}
