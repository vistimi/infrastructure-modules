SHELL:=/bin/bash
.SILENT:
MAKEFLAGS += --no-print-directory
MAKEFLAGS += --warn-undefined-variables

PATH_ABS_ROOT=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
PATH_REL_AWS=module/aws
PATH_ABS_AWS=${PATH_ABS_ROOT}/${PATH_REL_AWS}
PATH_REL_AWS_MICROSERVICE=${PATH_REL_AWS}/microservice
PATH_ABS_AWS_MICROSERVICE=${PATH_ABS_ROOT}/${PATH_REL_AWS_MICROSERVICE}
PATH_ABS_AWS_ECR=${PATH_ABS_ROOT}/${PATH_REL_AWS}/container/ecr
PATH_REL_TEST_MICROSERVICE=test/microservice

OVERRIDE_EXTENSION=override
export OVERRIDE_EXTENSION
export AWS_REGION AWS_PROFILE AWS_ACCOUNT_ID AWS_ACCESS_KEY AWS_SECRET_KEY ENVIRONMENT_NAME

.PHONY: build help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

fmt: ## Format all files
	terraform fmt -recursive

.ONESHELL: aws-auth
aws-auth:
	aws configure set aws_access_key_id ${AWS_ACCESS_KEY} --profile ${AWS_PROFILE}
	aws configure set --profile ${AWS_PROFILE} aws_secret_access_key ${AWS_SECRET_KEY} --profile ${AWS_PROFILE}
	aws configure set region ${AWS_REGION} --profile ${AWS_PROFILE}
	aws configure set output 'text' --profile ${AWS_PROFILE}
	make aws-auth-check
aws-auth-check:
	aws configure list
.ONESHELL: ecr-configure

gh-auth-check:
	gh auth status
.ONESHELL: gh-load-folder
gh-load-folder:
	echo GET Github folder:: ${REPOSITORY_PATH}
	$(eval res=$(shell curl -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/contents/${REPOSITORY_PATH}?ref=${BRANCH_NAME} | jq -c '.[] | .path'))
	for file in ${res}; do \
		echo GET Github file:: "$$file"
		make gh-load-file \
			OUTPUT_FOLDER=${OUTPUT_FOLDER} \
			REPOSITORY_PATH="$$file" \
			ORGANIZATION_NAME=${ORGANIZATION_NAME} \
			REPOSITORY_NAME=${REPOSITORY_NAME} \
			BRANCH_NAME=${BRANCH_NAME}; \
    done
gh-load-file:	
	curl -L -o ${OUTPUT_FOLDER}/$(shell basename ${REPOSITORY_PATH} | cut -d. -f1)_${OVERRIDE_EXTENSION}$(shell [[ "${REPOSITORY_PATH}" = *.* ]] && echo .$(shell basename ${REPOSITORY_PATH} | cut -d. -f2) || echo '') \
			-H "Accept: application/vnd.github.v3.raw" \
			-H "Authorization: Bearer ${GITHUB_TOKEN}" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			https://api.github.com/repos/${ORGANIZATION_NAME}/${REPOSITORY_NAME}/contents/${REPOSITORY_PATH}?ref=${BRANCH_NAME}

test: ## Setup the test environment, run the tests and clean the environment
	make test-prepare; \
	# # p1 will not mix the logs when multiple tests are used
	# go test -timeout 30m -p 1 -v -cover ./...; \
	make clean;
test-clean-cache:
	go clean -testcache;

SCRAPER_BACKEND_BRANCH_NAME ?= master
SCRAPER_FRONTEND_BRANCH_NAME ?= master
prepare: ## Setup the test environment
	make prepare-account-aws
	make prepare-scraper-backend BRANCH_NAME=${SCRAPER_BACKEND_BRANCH_NAME}
	make prepare-scraper-frontend BRANCH_NAME=${SCRAPER_FRONTEND_BRANCH_NAME}
prepare-account-aws:
	cat <<-EOF > ${PATH_ABS_AWS}/aws_account_override.hcl 
	locals {
		aws_account_region="${AWS_REGION}"
		aws_account_name="${AWS_PROFILE}"
		aws_account_id="${AWS_ACCOUNT_ID}"
	}
	EOF

.ONESHELL: prepare-scraper-backend
BRANCH_NAME ?= master
prepare-scraper-backend:
	$(eval GIT_NAME=github.com)
	$(eval ORGANIZATION_NAME=KookaS)
	$(eval PROJECT_NAME=scraper)
	$(eval SERVICE_NAME=backend)
	$(eval REPOSITORY_NAME=${PROJECT_NAME}-${SERVICE_NAME})
	$(eval OUTPUT_FOLDER=${PATH_REL_TEST_MICROSERVICE}/${REPOSITORY_NAME})
	$(eval COMMON_NAME="")
	$(eval CLOUD_HOST=aws)
	make gh-load-folder \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		BRANCH_NAME=${BRANCH_NAME} \
		REPOSITORY_PATH=config
	make prepare-scraper-backend-env \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		COMMON_NAME=${COMMON_NAME} \
		CLOUD_HOST=${CLOUD_HOST}

	cd ${PATH_ABS_AWS_MICROSERVICE}/${REPOSITORY_NAME}
	terragrunt init
make prepare-scraper-backend-env:
	$(eval MAKEFILE=$(shell find ${OUTPUT_FOLDER} -type f -name "*Makefile*"))
	make -f ${MAKEFILE} prepare \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		COMMON_NAME=${COMMON_NAME} \
		CLOUD_HOST=${CLOUD_HOST} \
		FLICKR_PRIVATE_KEY=123 \
		FLICKR_PUBLIC_KEY=123 \
		UNSPLASH_PRIVATE_KEY=123 \
		UNSPLASH_PUBLIC_KEY=123 \
		PEXELS_PUBLIC_KEY=123

.ONESHELL: prepare-scraper-frontend
BRANCH_NAME ?= master
prepare-scraper-frontend:
	$(eval GIT_NAME=github.com)
	$(eval ORGANIZATION_NAME=KookaS)
	$(eval PROJECT_NAME=scraper)
	$(eval SERVICE_NAME=frontend)
	$(eval REPOSITORY_NAME=${PROJECT_NAME}-${SERVICE_NAME})
	$(eval OUTPUT_FOLDER=${PATH_REL_TEST_MICROSERVICE}/${REPOSITORY_NAME})
	make gh-load-folder \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		BRANCH_NAME=${BRANCH_NAME} \
		REPOSITORY_PATH=config
	make prepare-scraper-frontend-env \
		OUTPUT_FOLDER=${OUTPUT_FOLDER}
	
	cd ${PATH_ABS_AWS_MICROSERVICE}/${REPOSITORY_NAME}
	terragrunt init
prepare-scraper-frontend-env:
	$(eval MAKEFILE=$(shell find ${OUTPUT_FOLDER} -type f -name "*Makefile*"))
	make -f ${MAKEFILE} prepare \
		OUTPUT_FOLDER=${OUTPUT_FOLDER} \
		NEXT_PUBLIC_API_URL="http://not-needed.com" \
		PORT="3000"

# TODO: actions/github-script@v6 to run nodejs in wf
# github-set-environment:
# # if ! curl -L --fail \
# # 	-H "Accept: application/vnd.github+json" \
# # 	-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# # 	-H "X-GitHub-Api-Version: 2022-11-28" \
# # 	https://api.github.com/repos/${REPOSITORY_NAME_OWNER}/${REPOSITORY_NAME_NAME}/environments/${GH_ENV}; then \
# # 	echo "Environemnt ${GH_ENV} is non existant and cannot be created with personal access token. Go create it on the repository ${REPOSITORY_NAME_OWNER}/${REPOSITORY_NAME_NAME}"; \
# # 	exit 10; \
# # fi
# 	echo GH_ENV=${GH_ENV}
# 	$(eval REPOSITORY_NAME_ID=$(shell curl -L \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repos/${REPOSITORY_NAME_OWNER}/${REPOSITORY_NAME_NAME} | jq '.id'))
# 	echo REPOSITORY_NAME_ID=${REPOSITORY_NAME_ID}
# 	$(eval GH_PUBLIC_KEY_ID=$(shell curl -L \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${REPOSITORY_NAME_ID}/environments/${GH_ENV}/secrets/public-key  | jq '.key_id'))
# 	echo GH_PUBLIC_KEY_ID=${GH_PUBLIC_KEY_ID}
# 	$(eval GH_ENV_PUBLIC_KEY=$(shell curl -L \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${REPOSITORY_NAME_ID}/environments/${GH_ENV}/secrets/public-key  | jq '.key'))
# 	echo GH_ENV_PUBLIC_KEY=${GH_ENV_PUBLIC_KEY}
# # curl -L \
# # 	-X POST \
# # 	-H "Accept: application/vnd.github+json" \
# # 	-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# # 	-H "X-GitHub-Api-Version: 2022-11-28" \
# # 	https://api.github.com/repositories/${REPOSITORY_NAME_ID}/environments/${GH_ENV}/variables \
# # 	-d '{"name":"MY_VAR","value":"vallll"}'
# 	make github-set-environment-secret REPOSITORY_NAME_ID=${REPOSITORY_NAME_ID} GH_ENV=${GH_ENV} GH_KEY_ID=${GH_PUBLIC_KEY_ID} GH_PUBLIC_KEY=${GH_ENV_PUBLIC_KEY} GH_SECRET_NAME=MY_SECRET GH_SECRET_VALUE=vallll
# 	# make github-set-environment-variable REPOSITORY_NAME_ID=${REPOSITORY_NAME_ID} GH_ENV=${GH_ENV} VAR_NAME=MY_VAR VAR_VALUE=vallll
# 	curl -L \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${REPOSITORY_NAME_ID}/environments/${GH_ENV}/secrets
# 	curl -L \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${REPOSITORY_NAME_ID}/environments/${GH_ENV}/variables
# github-set-environment-variable:
# 	curl -L \
# 		-X POST \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer <YOUR-TOKEN>"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${REPOSITORY_NAME_ID}/environments/${GH_ENV}/variables \
# 		-d '{"name":"${VAR_NAME}","value":"${VAR_VALUE}"}'
# github-set-environment-secret:
# 	echo set secret
# 	$(eval GH_SECRET_VALUE=$(shell echo "${GH_SECRET_VALUE}" | iconv -f utf-8))
# 	echo GH_SECRET_VALUE=${GH_SECRET_VALUE}
# 	# $(eval GH_PUBLIC_KEY=$(shell base64 -d <<< "${GH_PUBLIC_KEY}" | iconv -t utf-8))
# 	echo GH_PUBLIC_KEY=${GH_PUBLIC_KEY}

# 	gcc -o sodium_encoding sodium_encoding.c -lsodium
# 	$(eval GH_SECRET_VALUE_ENCR="$(shell ./sodium_encoding $(shell base64 -d <<< "${GH_PUBLIC_KEY}") ${GH_SECRET_VALUE})")
	
# 	echo GH_SECRET_VALUE_ENCR=${GH_SECRET_VALUE_ENCR}
# 	curl -L \
# 		-X PUT \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${REPOSITORY_NAME_ID}/environments/${GH_ENV}/secrets/${GH_SECRET_NAME} \
# 		-d '{"encrypted_value":${GH_SECRET_VALUE_ENCR},"key_id":"${GH_KEY_ID}"}';

.ONESHELL: clean
clean: ## Clean the test environment
	make nuke-region
	make nuke-vpc
	make nuke-global

	make clean-task-definition
	make clean-elb
	make clean-ecs

	make clean-local

clean-local: ## Clean the local files and folders
	echo "Delete state files..."; for filePath in $(shell find . -type f -name "*.tfstate"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete state backup files..."; for folderPath in $(shell find . -type f -name "terraform.tfstate.backup"); do echo $$folderPath; rm -Rf $$folderPath; done; \
	echo "Delete override files..."; for filePath in $(shell find . -type f -name "*_override.*"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete lock files..."; for folderPath in $(shell find . -type f -name ".terraform.lock.hcl"); do echo $$folderPath; rm -Rf $$folderPath; done;

	echo "Delete temp folder..."; for folderPath in $(shell find . -type d -name ".terraform"); do echo $$folderPath; rm -Rf $$folderPath; done;
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
	cloud-nuke aws --region ${AWS_REGION} --config .gruntwork/cloud-nuke/config.yaml --force;
nuke-vpc:
	cloud-nuke aws --region ${AWS_REGION} --resource-type vpc --force;
nuke-global:
	cloud-nuke aws --region global --config .gruntwork/cloud-nuke/config.yaml --force;

# clean-old: ## Clean the test environment that is old
# 	make nuke-old-region-exclude-vpc; \
# 	make clean-old-vpc;
# clean-old-vpc:
# 	make nuke-old-region-vpc;
# OLD=4h
# nuke-old-region-exclude-vpc:
# 	cloud-nuke aws --region ${AWS_REGION} --exclude-resource-type vpc --older-than $OLD --force;
# nuke-old-region-vpc:
# 	cloud-nuke aws --region ${AWS_REGION} --resource-type vpc --older-than $OLD --force;

# it needs the tfstate files which are generated with apply
graph:
	cat ${INFRAMAP_PATH}/terraform.tfstate | inframap generate --tfstate | dot -Tpng > ${INFRAMAP_PATH}/graph.png
graph-module-microservice-scraper-backend: ## Generate the graph for the scraper backend
	make graph INFRAMAP_PATH=${PATH_ABS_ROOT}/module/services/scraper-backend
graph-module-microservice-scraper-frontend: ## Generate the graph for the scraper frontend
	make graph INFRAMAP_PATH=${PATH_ABS_ROOT}/module/services/scraper-frontend

rover-vpc:
	make rover-docker ROVER_MODULE=modules/vpc
rover-docker:
	sudo rover -workingDir ${PATH_ABS_ROOT}/${ROVER_MODULE} -tfVarsFile ${PATH_ABS_ROOT}/${ROVER_MODULE}/terraform_override.tfvars -genImage true
