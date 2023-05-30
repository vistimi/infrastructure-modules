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

# Create ECR repository
if [[ $ECR_CREATE == true ]]; then
  aws ecr create-repository \
    --repository-name $COMMON_NAME \
    --image-scanning-configuration scanOnPush=true \
    --region $AWS_REGION \
    --output text \
    --query 'repository.repositoryUri'
fi

# Build, tag, and push image to Amazon ECR
export ECR_URI=$(aws ecr describe-repositories --repository-names $COMMON_NAME --output text --query "repositories[].[repositoryUri]")
docker build -t $ECR_URI/$IMAGE_TAG -f $DOCKER_FOLDER_PATH .
docker tag $(docker images -q $ECR_URI/$IMAGE_TAG) $ECR_URI:$IMAGE_TAG
docker push $ECR_URI:$IMAGE_TAG

# Wait for image to be available
aws ecr wait image-scan-complete --repository-name $COMMON_NAME --image-id imageTag=$IMAGE_TAG
aws ecr describe-images --repository-name $COMMON_NAME --image-ids imageTag=$IMAGE_TAG --output json