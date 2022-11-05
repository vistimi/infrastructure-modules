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

	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

var (
	bucket_name_mongodb  = "scraper-test-mongodb"
	bucket_name_pictures = "scraper-test-pictures"
)

// An example of how to test the simple Terraform module in examples/terraform-basic-example using Terratest.
func TestTerraformMongodbUnitTest(t *testing.T) {
	t.Parallel()
	id := uuid.New()
	bastion := true
	account_name := ""
	aws_region := "us-east-1"

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// Relative path to module
		TerraformDir: "",

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"aws_region":        aws_region,
			"data_storage_name": fmt.Sprintf("%s-%s-%s-mongodb", account_name, aws_region, "test"),
			"private_subnets": []string{
				"subnet-0f0c2f4eb7a73ae75",
				"subnet-05561191ab56acaec",
				"subnet-014b7854a7e66f5ef",
			},
			"public_subnets": []string{
				"subnet-053af9be74486bdec",
				"subnet-09a00f6bc7a216def",
				"subnet-06a9db64287e77a76",
			},
			"vpc_security_group_ids": []string{"sg-065fe4857db2112d9"},
			"vpc_id":                 "vpc-0ef51aa8c677274ce",
			"common_tags": map[string]string{
				"Region":      "us-east-1",
				"Project":     "scraper",
				"Environment": "test",
			},
			"ami_id":         "ami-09d3b3274b6c5d4aa",
			"instance_type":  "t2.micro",
			"user_data_path": "mongodb.sh",
			"user_data_args": map[string]string{
				"bucket_name_mount_helper": "global-mount-helper",
				"bucket_name_mongodb":      bucket_name_mongodb + id.String(),
				"bucket_name_pictures":     bucket_name_pictures + id.String(),
				"mongodb_version":          "6.0.1",
				"aws_region":               os.Getenv("AWS_REGION"),
				"aws_profile":              os.Getenv("AWS_PROFILE"),
				"aws_access_key":           os.Getenv("AWS_ACCESS_KEY"),
				"aws_secret_key":           os.Getenv("AWS_SECRET_KEY"),
			},
			"bastion": bastion,
		},

		RetryableTerraformErrors: map[string]string{
			"net/http: TLS handshake timeout": "Terraform bug",
		},
		MaxRetries:         3,
		TimeBetweenRetries: 3 * time.Second,
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
		publicInstanceIPBastion := terraform.Output(t, terraformOptions, "ec2_instance_bastion_public_ip")
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
