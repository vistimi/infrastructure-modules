# tests

## options

```hcl
terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../",

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"region": "us-east-1",
            ...
		},

		RetryableTerraformErrors: map[string]string{
			"net/http: TLS handshake timeout": "Terraform bug",
		},
		MaxRetries: 3,
		TimeBetweenRetries: 3*time.Second,
	})
```

## local

Use the `RunTestStage` functionnality to disable certain parts of the code, thus not needing to constantly destroy and redeploy the instances for the same test:

```hcl
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
```

If you need to disable one functionality:

```shell
SKIP_cleanup_mongodb
```

If you need to enable one functionality:

```shell
unset SKIP_cleanup_mongodb
```