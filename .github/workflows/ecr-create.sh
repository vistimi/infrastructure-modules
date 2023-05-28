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

# setup AWS CLI
aws --version
aws configure set aws_access_key_id $AWS_ACCESS_KEY
aws configure set aws_secret_access_key $AWS_SECRET_KEY
aws configure set region $AWS_REGION

# Get ECR login password
if [[ $AWS_CLI_SERVICE == ecr ]]; then
  export ECR_LOGIN_PASSWORD=$(aws ecr get-login-password --region $AWS_REGION)
elif [[ $AWS_CLI_SERVICE == ecr-public ]]; then
  export ECR_LOGIN_PASSWORD=$(aws ecr-public get-login-password --region $AWS_REGION)
fi

# login to ECR
if [[ $AWS_CLI_SERVICE == ecr ]]; then
  docker login --username AWS --password $ECR_LOGIN_PASSWORD $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
elif [[ $AWS_CLI_SERVICE == ecr-public ]]; then
  docker login --username AWS --password $ECR_LOGIN_PASSWORD public.ecr.aws
fi

# Create ECR repository
aws ecr create-repository \
  --repository-name $COMMON_NAME \
  --image-scanning-configuration scanOnPush=true \
  --region $AWS_REGION \
  --output text \
  --query 'repository.repositoryUri'

# Build, tag, and push image to Amazon ECR
export ECR_URI=$(aws ecr describe-repositories --repository-names $COMMON_NAME --output text --query "repositories[].[repositoryUri]")
  echo "ECR_URI= $ECR_URI"
  docker build -t $ECR_URI/$IMAGE_TAG -f $DOCKER_FOLDER_PATH .
  docker tag $(docker images -q $ECR_URI/$IMAGE_TAG) $ECR_URI:$IMAGE_TAG
  docker push $ECR_URI:$IMAGE_TAG

echo ECR_LOGIN_PASSWORD=$ECR_LOGIN_PASSWORD