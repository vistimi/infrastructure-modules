package test

import (
	"context"
	"flag"
	"fmt"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"go.mongodb.org/mongo-driver/mongo/readpref"
)

var (
	bucket_name_mongodb  = "scraper_test-env_test-mongodb"
	bucket_name_pictures = "scraper_test-env_test-pictures"
)

func testMongodbOperations() error {
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

// An example of how to test the simple Terraform module in examples/terraform-basic-example using Terratest.
func TestTerraformMongodbUpAndRunning(t *testing.T) {
	flag.Set("test.timeout", "5m0s")
	fmt.Println("timeout: " + flag.Lookup("test.timeout").Value.String())
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../",

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"region":                 "us-east-1",
			"subnet_id":              "subnet-0f0c2f4eb7a73ae75",
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
				"bucket_name_mongodb":      bucket_name_mongodb,
				"bucket_name_pictures":     bucket_name_pictures,
				"mongodb_version":          "6.0.1",
				"aws_region":               os.Getenv("AWS_REGION"),
				"aws_profile":              os.Getenv("AWS_PROFILE"),
				"aws_access_key":           os.Getenv("AWS_ACCESS_KEY"),
				"aws_secret_key":           os.Getenv("AWS_SECRET_KEY"),
			},
		},

		BackendConfig: map[string]interface{}{
			"bucket":         "terraform-state-backend-test-storage",
			"key":            "global/s3/terraform.tfstate",
			"region":         "us-east-1",
			"dynamodb_table": "terraform-state-backend-test-locks",
			"encrypt":        true,
		},
	})

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer terraform.Destroy(t, terraformOptions)
	defer func() {
		if r := recover(); r != nil {
			terraform.Destroy(t, terraformOptions)
		}
	}()

	// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
	terraform.InitAndApply(t, terraformOptions)

	// Run `terraform output` to get the values of output variables
	s3bucketMongodbArn := terraform.Output(t, terraformOptions, "s3_bucket_mongodb_arn")
	s3bucketpicturesArn := terraform.Output(t, terraformOptions, "s3_bucket_pictures_arn")

	// Verify we're getting back the outputs we expect
	assert.Equal(t, fmt.Sprintf("arn:aws:s3:::%s", bucket_name_mongodb), s3bucketMongodbArn)
	assert.Equal(t, fmt.Sprintf("arn:aws:s3:::%s", bucket_name_pictures), s3bucketpicturesArn)

	// test mongodb connection and operations
	err := testMongodbOperations()
	assert.Equal(t, nil, err)
}
