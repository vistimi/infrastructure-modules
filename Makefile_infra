# https://www.gnu.org/software/make/manual/html_node/Special-Targets.html#Special-Targets
# https://www.gnu.org/software/make/manual/html_node/Options-Summary.html

# use bash not sh
SHELL:= /bin/bash

PATH_ABS_ROOT=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
FILE_NAME = $(shell basename $(MAKEFILE_LIST))

GIT_SHA=$(shell git rev-parse HEAD) # latest commit hash
GIT_DIFF=$(shell git diff -s --exit-code || echo "-dirty") # If working copy has changes, append `-dirty` to hash
GIT_REV=$(GIT_SHA)$(GIT_DIFF)
BUILD_TIMESTAMP=$(shell date '+%F_%H:%M:%S')

OVERRIDE_EXTENSION=override

.SILENT:	# silent all commands below
# https://www.gnu.org/software/make/manual/html_node/Options-Summary.html
MAKEFLAGS += --no-print-directory	# stop printing entering/leaving directory messages
MAKEFLAGS += --warn-undefined-variables	# warn when an undefined variable is referenced
.ONESHELL: # run one shell per target

# error for undefined variables
check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $2, ($2))))

.PHONY: build help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

init:
	$(call check_defined, TERRAGRUNT_CONFIG_PATH)
	terragrunt init --terragrunt-non-interactive --terragrunt-working-dir ${TERRAGRUNT_CONFIG_PATH}
validate:
	$(call check_defined, TERRAGRUNT_CONFIG_PATH)
	terragrunt validate --terragrunt-non-interactive --terragrunt-working-dir ${TERRAGRUNT_CONFIG_PATH}
plan:
	$(call check_defined, TERRAGRUNT_CONFIG_PATH)
	terragrunt plan --terragrunt-non-interactive --terragrunt-working-dir ${TERRAGRUNT_CONFIG_PATH} -no-color -out=${OUTPUT_FILE} 2>&1
apply:
	$(call check_defined, TERRAGRUNT_CONFIG_PATH)
	terragrunt apply --terragrunt-non-interactive -auto-approve --terragrunt-working-dir ${TERRAGRUNT_CONFIG_PATH}
destroy-microservice:
	$(call check_defined, TERRAGRUNT_CONFIG_PATH)
	terragrunt destroy --terragrunt-non-interactive -auto-approve --terragrunt-working-dir ${TERRAGRUNT_CONFIG_PATH} -target module.microservice
output-microservice:
	$(call check_defined, TERRAGRUNT_CONFIG_PATH)
	terragrunt output --terragrunt-non-interactive --terragrunt-working-dir ${TERRAGRUNT_CONFIG_PATH} -json microservice | jq '.ecs.elb.lb_dns_name'


clean-cloudwatch:
	for alarmName in $(shell aws cloudwatch describe-alarms --query 'MetricAlarms[].AlarmName' | tr -d '[],'); do echo $$alarmName; aws cloudwatch delete-alarms --alarm-names $$alarmName; done;
clean-task-definition:
	for taskDefinition in $(shell aws ecs list-task-definitions --status ACTIVE --query 'taskDefinitionArns[]' | tr -d '[],'); do aws ecs deregister-task-definition --task-definition $$taskDefinition --query 'taskDefinition.taskDefinitionArn'; done;
clean-iam:
	# roles are attached to policies
	for roleName in $(shell aws iam list-roles --query 'Roles[].RoleName'); do echo $$roleArn; aws iam delete-role --role-name $$roleName; done; \
	for policyArn in $(shell aws iam list-policies --max-items 200 --no-only-attached --query 'Policies[].Arn' | tr -d '[],'); do echo $$policyArn; aws iam delete-policy --policy-arn $$policyArn; done;
clean-ec2:
	for launchTemplateId in $(shell aws ec2 describe-launch-templates --query 'LaunchTemplates[].LaunchTemplateId' | tr -d '[],'); do aws ec2 delete-launch-template --launch-template-id $$launchTemplateId --query 'LaunchTemplate.LaunchTemplateName'; done;
clean-elb:
	for targetGroupArn in $(shell aws elbv2 describe-target-groups --query 'TargetGroups[].TargetGroupArn' | tr -d '[],'); do echo $$targetGroupArn; aws elbv2 delete-target-group --target-group-arn $$targetGroupArn; done;
clean-ecs:
	for clusterArn in $(shell aws ecs describe-clusters --query 'clusters[].clusterArn' | tr -d '[],'); do echo $$clusterArn; aws ecs delete-cluster --cluster $$clusterArn; done;
	for capacityProviderArn in $(shell aws ecs describe-capacity-providers --query 'capacityProviders[].capacityProviderArn' | tr -d '[],'); do aws ecs   delete-capacity-provider --capacity-provider $$capacityProviderArn --query 'capacityProvider.capacityProviderArn'; done;

nuke-region:
	cloud-nuke aws --region ${AWS_REGION_NAME} --config .gruntwork/cloud-nuke/config.yaml --force;
nuke-vpc:
	cloud-nuke aws --region ${AWS_REGION_NAME} --resource-type vpc --force;
nuke-ecs:
	cloud-nuke aws --region ${AWS_REGION_NAME} --resource-type ecscluster --force;
nuke-global:
	cloud-nuke aws --region global --config .gruntwork/cloud-nuke/config.yaml --force;

USE_DEFAULT ?= false
aws-auth:
	$(call check_defined, AWS_ACCESS_KEY, AWS_SECRET_KEY, AWS_REGION_NAME)
	aws --version
	if [[ ${USE_DEFAULT} == false ]]; then
		$(call check_defined, AWS_PROFILE_NAME)
		aws configure set aws_access_key_id ${AWS_ACCESS_KEY} --profile ${AWS_PROFILE_NAME}
		aws configure set aws_secret_access_key ${AWS_SECRET_KEY} --profile ${AWS_PROFILE_NAME}
		aws configure set region ${AWS_REGION_NAME} --profile ${AWS_PROFILE_NAME}
		aws configure set output 'text' --profile ${AWS_PROFILE_NAME}
	else
		aws configure set aws_access_key_id ${AWS_ACCESS_KEY}
		aws configure set aws_secret_access_key ${AWS_SECRET_KEY}
		aws configure set region ${AWS_REGION_NAME}
		aws configure set output 'text'
	fi
aws-auth-check:
	aws configure list

ssh-auth:
	$(eval GIT_HOST=github.com)
	mkdir -p ${SSH_FOLDER}
	eval `ssh-agent -s`
	ssh-keyscan ${GIT_HOST} >> ${SSH_FOLDER}/known_hosts

gh-auth-check:
	gh auth status
gh-list-branches:
	$(call check_defined, GITHUB_TOKEN, ORGANIZATION_NAME, REPOSITORY_NAME)
	curl -s -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/branches | jq '.[].name'
gh-load-folder:
	$(call check_defined, OVERRIDE_EXTENSION, GITHUB_TOKEN, ORGANIZATION_NAME, REPOSITORY_NAME, BRANCH_NAME, REPOSITORY_CONFIG_PATH_FOLDER, TERRAGRUNT_CONFIG_PATH)
	echo GET Github folder:: ${REPOSITORY_CONFIG_PATH_FOLDER}@${BRANCH_NAME}
	$(eval filesPath=$(shell curl -s -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/contents/${REPOSITORY_CONFIG_PATH_FOLDER}?ref=${BRANCH_NAME} | jq -c '.[].path'))
	for filePath in ${filesPath}; do
		make -f ${PATH_ABS_ROOT}/${FILE_NAME} gh-load-file \
			REPOSITORY_CONFIG_PATH_FILE=$$filePath \
			TERRAGRUNT_CONFIG_PATH=${TERRAGRUNT_CONFIG_PATH} \
			OVERRIDE_EXTENSION=${OVERRIDE_EXTENSION} \
			GITHUB_TOKEN=${GITHUB_TOKEN} \
			ORGANIZATION_NAME=${ORGANIZATION_NAME} \
			REPOSITORY_NAME=${REPOSITORY_NAME} \
			BRANCH_NAME=${BRANCH_NAME}
	done
gh-load-file:
	$(call check_defined, REPOSITORY_CONFIG_PATH_FILE, OVERRIDE_EXTENSION, GITHUB_TOKEN, ORGANIZATION_NAME, REPOSITORY_NAME, BRANCH_NAME)
	echo GET Github file:: ${REPOSITORY_CONFIG_PATH_FILE}@${BRANCH_NAME}
	curl -s -L -o ${TERRAGRUNT_CONFIG_PATH}/$(shell basename ${REPOSITORY_CONFIG_PATH_FILE} | cut -d. -f1)_${OVERRIDE_EXTENSION}$(shell [[ "${REPOSITORY_CONFIG_PATH_FILE}" = *.* ]] && echo .$(shell basename ${REPOSITORY_CONFIG_PATH_FILE} | cut -d. -f2) || echo '') \
		-H "Accept: application/vnd.github.v3.raw" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/contents/${REPOSITORY_CONFIG_PATH_FILE}?ref=${BRANCH_NAME}
gh-get-default-branch:
	$(call check_defined, OVERRIDE_EXTENSION, GITHUB_TOKEN, ORGANIZATION_NAME, REPOSITORY_NAME)
	curl -s -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/branches

list-override-files:
	$(call check_defined, OVERRIDE_EXTENSION)
	find ./live -type f -name "*${OVERRIDE_EXTENSION}*"

# it needs the tfstate files which are generated with apply
graph:
	$(call check_defined, INFRAMAP_PATH)
	cat ${INFRAMAP_PATH}/terraform.tfstate | inframap generate --tfstate | dot -Tpng > ${INFRAMAP_PATH}//vpc/graph.png

rover:
	$(call check_defined, ROVER_PATH, OVERRIDE_EXTENSION)
	rover -workingDir ${ROVER_PATH} -tfVarsFile ${ROVER_PATH}/terraform_${OVERRIDE_EXTENSION}.tfvars -genImage true