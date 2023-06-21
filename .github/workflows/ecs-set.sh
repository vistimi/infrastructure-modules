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

# Update service
export LATEST_TASK_ARN=$(aws ecs list-task-definitions \
  --region $AWS_REGION \
  --family-prefix $COMMON_NAME \
  --sort DESC \
  --query 'taskDefinitionArns[0]' \
  --output text)
aws ecs update-service \
  --cluster $COMMON_NAME \
  --service $COMMON_NAME \
  --force-new-deployment \
  --region $AWS_REGION \
  --task-definition $LATEST_TASK_ARN \
  --desired-count $DESIRED_COUNT \
  --output json
# TODO: update asg desired amount

echo Wait for service $COMMON_NAME to be stable
sleep 30s
# aws ecs wait services-stable \
#     --cluster $COMMON_NAME \
#     --services $COMMON_NAME

# Wait for tasks
export TASKS=$(aws ecs list-tasks \
--region $AWS_REGION \
--cluster $COMMON_NAME \
--query 'taskArns[]' \
--output text)

echo Wait for tasks $TASKS to be RUNNING

# aws ecs wait tasks-running \
#   --region $AWS_REGION \
#   --cluster $COMMON_NAME \
#   --tasks $TASKS

export LATEST_TASK_DEFINITION_ARN=$(aws ecs list-task-definitions \
--region $AWS_REGION \
--family-prefix $COMMON_NAME \
--sort DESC \
--query 'taskDefinitionArns[0]' \
--output text)
for task in $TASKS; do
  export tasksDescription=$(aws ecs describe-tasks --region $AWS_REGION --cluster $COMMON_NAME --tasks $task --query 'tasks[]' --output json) || exit 1
  echo "tasksDescription=$tasksDescription"
  export latestStatus=$(jq -r  '.[]|.lastStatus' <<< $tasksDescription)
  export taskDefinitionArn=$(jq -r  '.[]|.taskDefinitionArn' <<< $tasksDescription)
  echo "Waiting for task $task to be RUNNING, currently $latestStatus"
  echo "Waiting for task $task to have definition ARN $LATEST_TASK_DEFINITION_ARN, currently $taskDefinitionArn"
  
  export i=0
  while [[ $latestStatus != "RUNNING" && $taskDefinitionArn != $LATEST_TASK_DEFINITION_ARN ]]; do
    export tasksDescription=$(aws ecs describe-tasks --region $AWS_REGION --cluster $COMMON_NAME --tasks $task --query 'tasks[]' --output json)
    export latestStatus=$(jq -r  '.[]|.lastStatus' <<< $tasksDescription)
    export taskDefinitionArn=$(jq -r  '.[]|.taskDefinitionArn' <<< $tasksDescription)
    echo "Waiting for task $task to be RUNNING, currently $latestStatus"
    echo "Waiting for task $task to have definition ARN $LATEST_TASK_DEFINITION_ARN, currently $taskDefinitionArn"
    sleep 10s

    if [ $i -gt 30 ] || [ "$latestStatus" = "STOPPED" ]; then exit 1; fi
    export i=$((i+1))
  done
done
