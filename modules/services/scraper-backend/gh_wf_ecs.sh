#!/bin/bash

for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)

   KEY_LENGTH=${#KEY}
   VALUE="${ARGUMENT:$KEY_LENGTH+1}"

   export "$KEY"="$VALUE"
done

gh workflow run $GH_WF_FILE --repo $GH_ORG/$GH_REPO --ref $GH_BRANCH\
    -f aws-account-name=$AWS_ACCOUNT_NAME \
    -f aws-region=$AWS_REGION \
    -f common-name=$COMMON_NAME 

echo "Sleep 10 seconds for spawning action"
sleep 10s
echo "Continue to check the status"
while [ $(gh run list --repo $GH_ORG/$GH_REPO --branch $GH_BRANCH --workflow $GH_WF_NAME --limit 1 | awk '{print $1}') != "completed" ]
do
    if [[ $(gh run list --repo $GH_ORG/$GH_REPO --branch $GH_BRANCH --workflow $GH_WF_NAME --limit 1 | awk '{print $1}')  =~ "could not find any workflows" ]]; then exit 1; fi
    echo "Waiting for status workflow to complete: "${workflowStatus}
    sleep 5s
done
echo "Workflow finished: "${workflowStatus}