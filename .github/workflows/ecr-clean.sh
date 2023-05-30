#!/bin/bash

# use arguments as key/value
for ARGUMENT in "$@"
do
  KEY=$(echo $ARGUMENT | cut -f1 -d=)

  KEY_LENGTH=${#KEY}
  VALUE="${ARGUMENT:$KEY_LENGTH+1}"

  export "$KEY"="$VALUE"
done

# fail if unset variable
set -u

# log
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>$LOG_FILE 2>&1

# setup AWS CLI
aws --version
aws configure set aws_access_key_id $AWS_ACCESS_KEY
aws configure set aws_secret_access_key $AWS_SECRET_KEY
aws configure set region $AWS_REGION

# login to ECR
if [[ $AWS_CLI_SERVICE == ecr ]]; then
  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
elif [[ $AWS_CLI_SERVICE == ecr-public ]]; then
  aws ecr-public get-login-password --region $AWS_REGION | docker login --username AWS ---password-stdin public.ecr.aws
fi

# Delete ECR repository
aws ecr delete-repository \
  --repository-name $COMMON_NAME \
  --force \
  --region $AWS_REGION \
  --output text \
  --query 'repository.registryId'