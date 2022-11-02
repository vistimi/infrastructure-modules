package test

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
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
func TestTerraformMongodbUnitTest(t *testing.T) {
	t.Parallel()
	id := uuid.New()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../",

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"region": "us-east-1",
			// "subnet_id":           "subnet-0f0c2f4eb7a73ae75",
			"subnet_id":              "subnet-053af9be74486bdec",
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
		},

		RetryableTerraformErrors: map[string]string{
			"net/http: TLS handshake timeout": "Terraform bug",
		},
		MaxRetries: 3,
		TimeBetweenRetries: 3*time.Second,
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

	test_structure.RunTestStage(t, "validate_mongodb", func() {
		s3bucketMongodbArn := terraform.Output(t, terraformOptions, "s3_bucket_mongodb_arn")
		s3bucketpicturesArn := terraform.Output(t, terraformOptions, "s3_bucket_pictures_arn")
		assert.Equal(t, fmt.Sprintf("arn:aws:s3:::%s", bucket_name_mongodb), s3bucketMongodbArn)
		assert.Equal(t, fmt.Sprintf("arn:aws:s3:::%s", bucket_name_pictures), s3bucketpicturesArn)

		err := testMongodbOperations()
		assert.Equal(t, nil, err)
	})
}
