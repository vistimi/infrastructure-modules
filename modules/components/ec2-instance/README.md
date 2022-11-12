# mognodb.sh

The `HOME` can be found on the ec2 instance with `echo ~/` and `UID` with `echo ${UID}`

```
"ami_id":         "ami-09d3b3274b6c5d4aa",
"instance_type":  "t2.micro",
"user_data_path": "mongodb.sh",
"user_data_args": map[string]string{
    "HOME":                 "/home/ec2-user",
    "UID":                  "1000",
    "bucket_name_mongodb":  "",
    "bucket_name_pictures": "",
    "mongodb_version":      "6.0.1",
},
"bastion": true,
```