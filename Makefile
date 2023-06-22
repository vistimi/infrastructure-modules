SHELL:=/bin/bash
.SILENT:
MAKEFLAGS += --no-print-directory
MAKEFLAGS += --warn-undefined-variables

PATH_ABS_ROOT=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
PATH_REL_AWS=module/aws
PATH_ABS_AWS=${PATH_ABS_ROOT}/${PATH_REL_AWS}
PATH_REL_AWS_MICROSERVICE=${PATH_REL_AWS}/microservice
PATH_ABS_AWS_MICROSERVICE=${PATH_ABS_ROOT}/${PATH_REL_AWS_MICROSERVICE}
PATH_ABS_AWS_VPC=${PATH_ABS_ROOT}/${PATH_REL_AWS}/vpc
PATH_ABS_AWS_ECR=${PATH_ABS_ROOT}/${PATH_REL_AWS}/container/ecr
PATH_REL_TEST_MICROSERVICE=test/microservice

OVERRIDE_EXTENSION=override
export OVERRIDE_EXTENSION
export AWS_REGION AWS_PROFILE AWS_ACCOUNT_ID AWS_ACCESS_KEY AWS_SECRET_KEY ENVIRONMENT_NAME
export OUTPUT_FOLDER GH_ORG GH_REPO GH_BRANCH

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
	$(eval res=$(shell curl -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/${GH_ORG}/${GH_REPO}/contents/${GH_PATH}?ref=${GH_BRANCH} | jq -c '.[] | .path'))
	for file in ${res}; do \
		make gh-load-file OUTPUT_FOLDER=${OUTPUT_FOLDER} GH_PATH="$$file"; \
    done
gh-load-file:
	curl -L -o ${OUTPUT_FOLDER}/$(shell basename ${GH_PATH} | cut -d. -f1)_${OVERRIDE_EXTENSION}$(shell [[ "${GH_PATH}" = *.* ]] && echo .$(shell basename ${GH_PATH} | cut -d. -f2) || echo '') \
			-H "Accept: application/vnd.github.v3.raw" \
			-H "Authorization: Bearer ${GITHUB_TOKEN}" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			https://api.github.com/repos/${GH_ORG}/${GH_REPO}/contents/${GH_PATH}?ref=${GH_BRANCH}

test: ## Setup the test environment, run the tests and clean the environment
	make test-prepare; \
	# # p1 will not mix the logs when multiple tests are used
	# go test -timeout 30m -p 1 -v -cover ./...; \
	make clean;
test-clean-cache:
	go clean -testcache;

prepare: ## Setup the test environment
	make prepare-account-aws
	make set-module-vpc
	make prepare-scraper-backend GH_BRANCH=${SCRAPER_BACKEND_BRANCH_NAME}
	make prepare-scraper-frontend GH_BRANCH=${SCRAPER_FRONTEND_BRANCH_NAME}
prepare-account-aws:
	cat <<-EOF > ${PATH_ABS_AWS}/aws_account_override.hcl 
	locals {
		aws_account_region="${AWS_REGION}"
		aws_account_name="${AWS_PROFILE}"
		aws_account_id="${AWS_ACCOUNT_ID}"
	}
	EOF
.ONESHELL: prepare-module-microservice-scraper-frontend
set-module-vpc:
	if [ ! -e ${PATH_ABS_AWS_VPC}/terraform.tfstate ]; then

		cat <<-EOF > ${PATH_ABS_AWS_VPC}/terraform_override.tfvars 
		aws_region="${AWS_REGION}"
		vpc_name="$(shell echo $(AWS_PROFILE) | tr A-Z a-z)-${AWS_REGION}-test-vpc"
		common_tags={Region: "${AWS_REGION}"}
		vpc_cidr_ipv4="1.0.0.0/16"
		enable_nat=false
		EOF

		cd ${PATH_ABS_AWS_VPC}
		terragrunt init
		terragrunt apply -auto-approve
	fi
.ONESHELL: prepare-scraper-backend
prepare-scraper-backend:
	$(eval GH_ORG=KookaS)
	$(eval GH_REPO=scraper-backend)
	$(eval OUTPUT_FOLDER=${PATH_REL_TEST_MICROSERVICE}/${GH_REPO})
	$(eval MAKEFILE=$(shell find ${OUTPUT_FOLDER} -type f -name "*Makefile*"))
	make gh-load-folder GH_PATH=config
	make -f ${MAKEFILE} prepare \
		COMMON_NAME="" \
		CLOUD_HOST=aws \
		FLICKR_PRIVATE_KEY=123 \
		FLICKR_PUBLIC_KEY=123 \
		UNSPLASH_PRIVATE_KEY=123 \
		UNSPLASH_PUBLIC_KEY=123 \
		PEXELS_PUBLIC_KEY=123

	cd ${PATH_ABS_ROOT}/${PATH_REL_AWS_MICROSERVICE}/${GH_REPO}
	terragrunt init
.ONESHELL: prepare-scraper-frontend
prepare-scraper-frontend:
	$(eval GH_ORG=KookaS)
	$(eval GH_REPO=scraper-frontend)
	$(eval OUTPUT_FOLDER=${PATH_REL_TEST_MICROSERVICE}/${GH_REPO})
	$(eval MAKEFILE=test/microservice/${GH_REPO}/Makefile_${OVERRIDE_EXTENSION})
	make gh-load-folder GH_PATH=config
	make -f ${MAKEFILE} prepare \
		NEXT_PUBLIC_API_URL="not-needed" \
		PORT=3000

	cd ${PATH_ABS_ROOT}/${PATH_REL_AWS_MICROSERVICE}/${GH_REPO}
	terragrunt init

# github-set-environment:
# # if ! curl -L --fail \
# # 	-H "Accept: application/vnd.github+json" \
# # 	-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# # 	-H "X-GitHub-Api-Version: 2022-11-28" \
# # 	https://api.github.com/repos/${GH_REPO_OWNER}/${GH_REPO_NAME}/environments/${GH_ENV}; then \
# # 	echo "Environemnt ${GH_ENV} is non existant and cannot be created with personal access token. Go create it on the repository ${GH_REPO_OWNER}/${GH_REPO_NAME}"; \
# # 	exit 10; \
# # fi
# 	echo GH_ENV=${GH_ENV}
# 	$(eval GH_REPO_ID=$(shell curl -L \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repos/${GH_REPO_OWNER}/${GH_REPO_NAME} | jq '.id'))
# 	echo GH_REPO_ID=${GH_REPO_ID}
# 	$(eval GH_PUBLIC_KEY_ID=$(shell curl -L \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${GH_REPO_ID}/environments/${GH_ENV}/secrets/public-key  | jq '.key_id'))
# 	echo GH_PUBLIC_KEY_ID=${GH_PUBLIC_KEY_ID}
# 	$(eval GH_ENV_PUBLIC_KEY=$(shell curl -L \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${GH_REPO_ID}/environments/${GH_ENV}/secrets/public-key  | jq '.key'))
# 	echo GH_ENV_PUBLIC_KEY=${GH_ENV_PUBLIC_KEY}
# # curl -L \
# # 	-X POST \
# # 	-H "Accept: application/vnd.github+json" \
# # 	-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# # 	-H "X-GitHub-Api-Version: 2022-11-28" \
# # 	https://api.github.com/repositories/${GH_REPO_ID}/environments/${GH_ENV}/variables \
# # 	-d '{"name":"MY_VAR","value":"vallll"}'
# 	make github-set-environment-secret GH_REPO_ID=${GH_REPO_ID} GH_ENV=${GH_ENV} GH_KEY_ID=${GH_PUBLIC_KEY_ID} GH_PUBLIC_KEY=${GH_ENV_PUBLIC_KEY} GH_SECRET_NAME=MY_SECRET GH_SECRET_VALUE=vallll
# 	# make github-set-environment-variable GH_REPO_ID=${GH_REPO_ID} GH_ENV=${GH_ENV} VAR_NAME=MY_VAR VAR_VALUE=vallll
# 	curl -L \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${GH_REPO_ID}/environments/${GH_ENV}/secrets
# 	curl -L \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${GH_REPO_ID}/environments/${GH_ENV}/variables
# github-set-environment-variable:
# 	curl -L \
# 		-X POST \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer <YOUR-TOKEN>"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${GH_REPO_ID}/environments/${GH_ENV}/variables \
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
# 		https://api.github.com/repositories/${GH_REPO_ID}/environments/${GH_ENV}/secrets/${GH_SECRET_NAME} \
# 		-d '{"encrypted_value":${GH_SECRET_VALUE_ENCR},"key_id":"${GH_KEY_ID}"}';

.ONESHELL: clean
clean: ## Clean the test environment
	make nuke-region-exclude-vpc
	make clean-vpc
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
clean-vpc:
	# if [ ! -e ${PATH_ABS_AWS_VPC}/terraform.tfstate ]; then \
	# 	make nuke-region-vpc; \
	# else \
	# 	echo "Deleting network acl..."; for networkAclId in $(aws ec2 describe-network-acls --query 'NetworkAcls[].NetworkAclId'); do aws ec2 delete-network-acl --network-acl-id $networkAclId; done; \
	# 	cd ${PATH_ABS_AWS_VPC}; \
	# 	terragrunt destroy -auto-approve; \
	# 	rm ${PATH_ABS_AWS_VPC}/terraform.tfstate; \
	# fi
	make nuke-region-vpc;

nuke-all: ## Nuke all resources in all regions
	cloud-nuke aws;
nuke-region-exclude-vpc: ## Nuke within the user's region all resources excluding vpc, e.g. for repeating tests manually
	cloud-nuke aws --region ${AWS_REGION} --exclude-resource-type vpc --config .gruntwork/cloud-nuke/config.yaml --force;
nuke-region-vpc:
	cloud-nuke aws --region ${AWS_REGION} --resource-type vpc --config .gruntwork/cloud-nuke/config.yaml --force;
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
	cat ${INFRAMAP_PATH}/terraform.tfstate | inframap generate --tfstate | dot -Tpng > ${INFRAMAP_PATH}//vpc/graph.png
graph-module-vpc: ## Generate the graph for the VPC
	make graph INFRAMAP_PATH=${PATH_ABS_ROOT}/module/vpc
graph-module-microservice-scraper-backend: ## Generate the graph for the scraper backend
	make graph INFRAMAP_PATH=${PATH_ABS_ROOT}/module/services/scraper-backend
graph-module-microservice-scraper-frontend: ## Generate the graph for the scraper frontend
	make graph INFRAMAP_PATH=${PATH_ABS_ROOT}/module/services/scraper-frontend

rover-vpc:
	make rover-docker ROVER_MODULE=modules/vpc
rover-docker:
	sudo rover -workingDir ${PATH_ABS_ROOT}/${ROVER_MODULE} -tfVarsFile ${PATH_ABS_ROOT}/${ROVER_MODULE}/terraform_override.tfvars -genImage true
