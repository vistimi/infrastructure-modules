# https://www.gnu.org/software/make/manual/html_node/Special-Targets.html#Special-Targets
# https://www.gnu.org/software/make/manual/html_node/Options-Summary.html

# use bash not sh
SHELL:= /bin/bash

GIT_SHA=$(shell git rev-parse HEAD) # latest commit hash
GIT_DIFF=$(shell git diff -s --exit-code || echo "-dirty") # If working copy has changes, append `-dirty` to hash
GIT_REV=$(GIT_SHA)$(GIT_DIFF)
BUILD_TIMESTAMP=$(shell date '+%F_%H:%M:%S')

# absolute path
PATH_ABS_ROOT=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
PATH_REL_LIVE=live
PATH_ABS_LIVE=${PATH_ABS_ROOT}/${PATH_REL_LIVE}
PATH_REL_AWS=live/aws
PATH_ABS_AWS=${PATH_ABS_ROOT}/${PATH_REL_AWS}

OVERRIDE_EXTENSION=override

.SILENT:	# silent all commands below
# https://www.gnu.org/software/make/manual/html_node/Options-Summary.html
MAKEFLAGS += --no-print-directory	# stop printing entering/leaving directory messages
MAKEFLAGS += --warn-undefined-variables	# warn when an undefined variable is referenced

.PHONY: build help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

fmt: ## Format all files
	terragrunt hclfmt

.ONESHELL: clean
clean: ## Clean the test environment
	make nuke-region
	make nuke-ecs
	make nuke-vpc
	make nuke-global

	make clean-task-definition
	make clean-elb
	make clean-ecs

	make clean-local
clean-local: ## Clean the local files and folders
	echo "Delete state backup files..."; for folderPath in $(shell find . -type f -name ".terraform.lock.hcl"); do echo $$folderPath; rm -Rf $$folderPath; done; \
	echo "Delete override files..."; for filePath in $(shell find . -type f -name "*override*"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete temp folder..."; for folderPath in $(shell find . -type d -name ".terragrunt-cache"); do echo $$folderPath; rm -Rf $$folderPath; done;
clean-cloudwatch:
	for alarmName in $(shell aws cloudwatch describe-alarms --query 'MetricAlarms[].AlarmName'); do echo $$alarmName; aws cloudwatch delete-alarms --alarm-names $$alarmName; done;
clean-task-definition:
	for taskDefinition in $(shell aws ecs list-task-definitions --status ACTIVE --query 'taskDefinitionArns[]'); do aws ecs deregister-task-definition --task-definition $$taskDefinition --query 'taskDefinition.taskDefinitionArn'; done;
clean-iam:
	# roles are attached to policies
	for roleName in $(shell aws iam list-roles --query 'Roles[].RoleName'); do echo $$roleArn; aws iam delete-role --role-name $$roleName; done; \
	for policyArn in $(shell aws iam list-policies --max-items 200 --no-only-attached --query 'Policies[].Arn'); do echo $$policyArn; aws iam delete-policy --policy-arn $$policyArn; done;
clean-ec2:
	for launchTemplateId in $(shell aws ec2 describe-launch-templates --query 'LaunchTemplates[].LaunchTemplateId'); do aws ec2 delete-launch-template --launch-template-id $$launchTemplateId --query 'LaunchTemplate.LaunchTemplateName'; done;
clean-elb:
	for targetGroupArn in $(shell aws elbv2 describe-target-groups --query 'TargetGroups[].TargetGroupArn'); do echo $$targetGroupArn; aws elbv2 delete-target-group --target-group-arn $$targetGroupArn; done;
clean-ecs:
	for clusterArn in $(shell aws ecs describe-clusters --query 'clusters[].clusterArn'); do echo $$clusterArn; aws ecs delete-cluster --cluster $$clusterArn; done;
	for capacityProviderArn in $(shell aws ecs describe-capacity-providers --query 'capacityProviders[].capacityProviderArn'); do aws ecs   delete-capacity-provider --capacity-provider $$capacityProviderArn --query 'capacityProvider.capacityProviderArn'; done;

nuke-region:
	cloud-nuke aws --region ${AWS_REGION_NAME} --config .gruntwork/cloud-nuke/config.yaml --force;
nuke-vpc:
	cloud-nuke aws --region ${AWS_REGION_NAME} --resource-type vpc --force;
nuke-ecs:
	cloud-nuke aws --region ${AWS_REGION_NAME} --resource-type ecscluster --force;
nuke-global:
	cloud-nuke aws --region global --config .gruntwork/cloud-nuke/config.yaml --force;

.ONESHELL: aws-auth
aws-auth:
	aws --version
	aws configure set aws_access_key_id ${AWS_ACCESS_KEY} --profile ${AWS_PROFILE_NAME}
	aws configure set --profile ${AWS_PROFILE_NAME} aws_secret_access_key ${AWS_SECRET_KEY} --profile ${AWS_PROFILE_NAME}
	aws configure set region ${AWS_REGION_NAME} --profile ${AWS_PROFILE_NAME}
	aws configure set output 'text' --profile ${AWS_PROFILE_NAME}
	make aws-auth-check
aws-auth-check:
	aws configure list
.ONESHELL: ecr-configure

ssh-auth:
	$(eval GIT_HOST=github.com)
	mkdir -p ${SSH_FOLDER}
	eval `ssh-agent -s`
	ssh-keyscan ${GIT_HOST} >> ${SSH_FOLDER}/known_hosts

gh-auth-check:
	gh auth status
gh-list-branches:
	curl -s -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/branches | jq '.[].name'
.ONESHELL: gh-load-folder
gh-load-folder:
	echo GET Github folder:: ${REPOSITORY_CONFIG_PATH_FOLDER}@${BRANCH_NAME}
	$(eval filesPath=$(shell curl -s -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/contents/${REPOSITORY_CONFIG_PATH_FOLDER}?ref=${BRANCH_NAME} | jq -c '.[].path'))
	for filePath in ${filesPath}; do		
		make gh-load-config-file \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			GITHUB_TOKEN=${GITHUB_TOKEN} \
			REPOSITORY_CONFIG_PATH_FILE="$$filePath" \
			ORGANIZATION_NAME=${ORGANIZATION_NAME} \
			TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
			BRANCH_NAME=${BRANCH_NAME}; \
    done
gh-load-config-file:
	echo GET Github file:: ${REPOSITORY_CONFIG_PATH_FILE}@${BRANCH_NAME}
	curl -s -L -o ${TERRAGRUNT_CONFIG_PATH}/$(shell basename ${REPOSITORY_CONFIG_PATH_FILE} | cut -d. -f1)_${OVERRIDE_EXTENSION}$(shell [[ "${REPOSITORY_CONFIG_PATH_FILE}" = *.* ]] && echo .$(shell basename ${REPOSITORY_CONFIG_PATH_FILE} | cut -d. -f2) || echo '') \
			-H "Accept: application/vnd.github.v3.raw" \
			-H "Authorization: Bearer ${GITHUB_TOKEN}" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/contents/${REPOSITORY_CONFIG_PATH_FILE}?ref=${BRANCH_NAME}
gh-get-default-branch:
	curl -s -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/branches

list-override-files:
	find ./live -type f -name "*${OVERRIDE_EXTENSION}*"

# it needs the tfstate files which are generated with apply
graph:
	cat ${INFRAMAP_PATH}/terraform.tfstate | inframap generate --tfstate | dot -Tpng > ${INFRAMAP_PATH}//vpc/graph.png
graph-scraper-vpc: ## Generate the graph for the VPC
	make graph INFRAMAP_PATH=${ROOT_PATH}/live/region/vpc

rover-docker:
	sudo rover -workingDir ${ROVER_PATH} -tfVarsFile ${ROVER_PATH}/terraform_${OVERRIDE_EXTENSION}.tfvars -genImage true
rover-vpc: ## Generate the rover for the VPC
	make rover-docker ROVER_PATH=${ROOT_PATH}/live/region/vpc