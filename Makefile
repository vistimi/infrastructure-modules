# https://www.gnu.org/software/make/manual/html_node/Special-Targets.html#Special-Targets
# https://www.gnu.org/software/make/manual/html_node/Options-Summary.html

# use bash not sh
SHELL:= /bin/bash

.PHONY: build help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

GIT_SHA=$(shell git rev-parse HEAD) # latest commit hash
GIT_DIFF=$(shell git diff -s --exit-code || echo "-dirty") # If working copy has changes, append `-dirty` to hash
GIT_REV=$(GIT_SHA)$(GIT_DIFF)
BUILD_TIMESTAMP=$(shell date '+%F_%H:%M:%S')

# absolute path
ROOT_PATH=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
VPC_PATH=${ROOT_PATH}/modules/vpc

.SILENT:	# silent all commands below
MAKEFLAGS += --no-print-directory	# stop printing entering/leaving directory messages

fmt: ## Format all files
	terraform fmt -recursive

test: ## Setup the test environment, run the tests and clean the environment
	make clean; \
	make prepare; \
	cd ${ROOT_PATH}; \
	# p1 will not mix the logs when multiple tests are used
	go test -timeout 30m -p 1 -v -cover ./...; \
	make clean;
test-clean-cache:
	go clean -testcache;

prepare: ## Setup the test environment
	# make github-cli-auth; \
	make prepare-account; \
	make prepare-modules-vpc; \
	# make prepare-modules-infrastructure-modules; \
	make prepare-modules-services-scraper-backend; \
	make prepare-modules-services-scraper-frontend;
prepare-account:
	echo 'locals {' 							> 	${ROOT_PATH}/modules/account.hcl; \
	echo 'aws_account_region="${AWS_REGION}"' 	>> 	${ROOT_PATH}/modules/account.hcl; \
	echo 'aws_account_name="${AWS_PROFILE}"' 	>> 	${ROOT_PATH}/modules/account.hcl; \
	echo 'aws_account_id="${AWS_ID}"' 			>> 	${ROOT_PATH}/modules/account.hcl; \
	echo '}'									>> 	${ROOT_PATH}/modules/account.hcl;
prepare-modules-vpc:
	# remove the state file in the vpc folder to create a new one \
	if [ ! -e ${VPC_PATH}/terraform.tfstate ]; then \
		echo 'aws_region="${AWS_REGION}"' 													> 	${VPC_PATH}/terraform_override.tfvars; \
		echo 'vpc_name="$(shell echo $(AWS_PROFILE) | tr A-Z a-z)-${AWS_REGION}-test-vpc"' 	>> 	${VPC_PATH}/terraform_override.tfvars; \
		echo 'common_tags={Region: "${AWS_REGION}"}' 										>> 	${VPC_PATH}/terraform_override.tfvars; \
		echo 'vpc_cidr_ipv4="1.0.0.0/16"' 													>> 	${VPC_PATH}/terraform_override.tfvars; \
		echo 'enable_nat=false' 															>> 	${VPC_PATH}/terraform_override.tfvars; \
		cd ${VPC_PATH}; \
		terragrunt init; \
		terragrunt apply -auto-approve; \
	fi
# prepare-modules-infrastructure-modules:
# 	make github-set-environment GH_REPO_OWNER=KookaS GH_REPO_NAME=infrastructure-modules GH_ENV=KookaS
# TODO: add other language and github app
prepare-modules-services-scraper-backend:
	$(eval MODULE_PATH=modules/services/scraper-backend)
	$(eval GH_ORG=KookaS)
	$(eval GH_REPO=scraper-backend)
	$(eval GH_BRANCH=master)
	make github-load-file MODULE_PATH=${MODULE_PATH} GITHUB_TOKEN=${GITHUB_TOKEN} GH_ORG=${GH_ORG} GH_REPO=${GH_REPO} GH_BRANCH=${GH_BRANCH} GH_PATH=config/config.yml; \
	make github-load-file MODULE_PATH=${MODULE_PATH} GITHUB_TOKEN=${GITHUB_TOKEN} GH_ORG=${GH_ORG} GH_REPO=${GH_REPO} GH_BRANCH=${GH_BRANCH} GH_PATH=config/config.go; \
	sed -i 's/package .*/package scraper_backend_test/' ${MODULE_PATH}/config_override.go; \
	cd ${ROOT_PATH}/${MODULE_PATH}; \
	terragrunt init;
prepare-modules-services-scraper-frontend:
	$(eval MODULE_PATH=modules/services/scraper-frontend)
	$(eval GH_ORG=KookaS)
	$(eval GH_REPO=scraper-frontend)
	$(eval GH_BRANCH=master)
	make github-load-file MODULE_PATH=${MODULE_PATH} GITHUB_TOKEN=${GITHUB_TOKEN} GH_ORG=${GH_ORG} GH_REPO=${GH_REPO} GH_BRANCH=${GH_BRANCH} GH_PATH=config/config.yml; \
	cd ${ROOT_PATH}/${MODULE_PATH}; \
	terragrunt init;
# github-cli-auth:
# 	gh auth login --with-token ${GITHUB_TOKEN}
# 	gh auth status
github-load-file:
	curl -L -o ${MODULE_PATH}/$(shell basename ${GH_PATH} | cut -d. -f1)_override.$(shell basename ${GH_PATH} | cut -d. -f2) \
			-H "Accept: application/vnd.github.v3.raw" \
			-H "Authorization: Bearer ${GITHUB_TOKEN}" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			https://api.github.com/repos/${GH_ORG}/${GH_REPO}/contents/${GH_PATH}?ref=${GH_BRANCH}
github-set-environment:
# if ! curl -L --fail \
# 	-H "Accept: application/vnd.github+json" \
# 	-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 	-H "X-GitHub-Api-Version: 2022-11-28" \
# 	https://api.github.com/repos/${GH_REPO_OWNER}/${GH_REPO_NAME}/environments/${GH_ENV}; then \
# 	echo "Environemnt ${GH_ENV} is non existant and cannot be created with personal access token. Go create it on the repository ${GH_REPO_OWNER}/${GH_REPO_NAME}"; \
# 	exit 10; \
# fi
	echo GH_ENV=${GH_ENV}
	$(eval GH_REPO_ID=$(shell curl -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/${GH_REPO_OWNER}/${GH_REPO_NAME} | jq '.id'))
	echo GH_REPO_ID=${GH_REPO_ID}
	$(eval GH_PUBLIC_KEY_ID=$(shell curl -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repositories/${GH_REPO_ID}/environments/${GH_ENV}/secrets/public-key  | jq '.key_id'))
	echo GH_PUBLIC_KEY_ID=${GH_PUBLIC_KEY_ID}
	$(eval GH_ENV_PUBLIC_KEY=$(shell curl -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repositories/${GH_REPO_ID}/environments/${GH_ENV}/secrets/public-key  | jq '.key'))
	echo GH_ENV_PUBLIC_KEY=${GH_ENV_PUBLIC_KEY}
# curl -L \
# 	-X POST \
# 	-H "Accept: application/vnd.github+json" \
# 	-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 	-H "X-GitHub-Api-Version: 2022-11-28" \
# 	https://api.github.com/repositories/${GH_REPO_ID}/environments/${GH_ENV}/variables \
# 	-d '{"name":"MY_VAR","value":"vallll"}'
	make github-set-environment-secret GH_REPO_ID=${GH_REPO_ID} GH_ENV=${GH_ENV} GH_KEY_ID=${GH_PUBLIC_KEY_ID} GH_PUBLIC_KEY=${GH_ENV_PUBLIC_KEY} GH_SECRET_NAME=MY_SECRET GH_SECRET_VALUE=vallll
	# make github-set-environment-variable GH_REPO_ID=${GH_REPO_ID} GH_ENV=${GH_ENV} VAR_NAME=MY_VAR VAR_VALUE=vallll
	curl -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repositories/${GH_REPO_ID}/environments/${GH_ENV}/secrets
	curl -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repositories/${GH_REPO_ID}/environments/${GH_ENV}/variables
github-set-environment-variable:
	curl -L \
		-X POST \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer <YOUR-TOKEN>"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repositories/${GH_REPO_ID}/environments/${GH_ENV}/variables \
		-d '{"name":"${VAR_NAME}","value":"${VAR_VALUE}"}'
github-set-environment-secret:
	echo set secret
	$(eval GH_SECRET_VALUE=$(shell echo "${GH_SECRET_VALUE}" | iconv -f utf-8))
	echo GH_SECRET_VALUE=${GH_SECRET_VALUE}
	# $(eval GH_PUBLIC_KEY=$(shell base64 -d <<< "${GH_PUBLIC_KEY}" | iconv -t utf-8))
	echo GH_PUBLIC_KEY=${GH_PUBLIC_KEY}

	gcc -o sodium_encoding sodium_encoding.c -lsodium
	$(eval GH_SECRET_VALUE_ENCR="$(shell ./sodium_encoding $(shell base64 -d <<< "${GH_PUBLIC_KEY}") ${GH_SECRET_VALUE})")
	
	echo GH_SECRET_VALUE_ENCR=${GH_SECRET_VALUE_ENCR}
	curl -L \
		-X PUT \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repositories/${GH_REPO_ID}/environments/${GH_ENV}/secrets/${GH_SECRET_NAME} \
		-d '{"encrypted_value":${GH_SECRET_VALUE_ENCR},"key_id":"${GH_KEY_ID}"}';


clean: ## Clean the test environment
	make nuke-region-exclude-vpc;
	make clean-vpc;
	make nuke-global;

	# make clean-cloudwatch; \
	make clean-task-definition; \
	# make clean-registries; \
	# make clean-iam; \
	# make clean-ec2; \
	make clean-elb; \
	make clean-ecs; \

	echo "Delete state files..."; for filePath in $(shell find . -type f -name "*.tfstate"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete state backup files..."; for folderPath in $(shell find . -type f -name "terraform.tfstate.backup"); do echo $$folderPath; rm -Rf $$folderPath; done; \
	echo "Delete override files..."; for filePath in $(shell find . -type f -name "*_override.*"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete lock files..."; for folderPath in $(shell find . -type f -name "terraform.lock.hcl"); do echo $$folderPath; rm -Rf $$folderPath; done;

	echo "Delete temp folder..."; for folderPath in $(shell find . -type d -name ".terraform"); do echo $$folderPath; rm -Rf $$folderPath; done;
clean-cloudwatch:
	for alarmName in $(shell aws cloudwatch describe-alarms --query 'MetricAlarms[].AlarmName'); do echo $$alarmName; aws cloudwatch delete-alarms --alarm-names $$alarmName; done;
clean-task-definition:
	for taskDefinition in $(shell aws ecs list-task-definitions --status ACTIVE --query 'taskDefinitionArns[]'); do aws ecs deregister-task-definition --task-definition $$taskDefinition --query 'taskDefinition.taskDefinitionArn'; done;
clean-registries:
	for repositoryName in $(shell aws ecr describe-repositories --query 'repositories[].repositoryName'); do aws ecr delete-repository --repository-name $$repositoryName --force --query 'repository.repositoryName'; done;
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
	# if [ ! -e ${VPC_PATH}/terraform.tfstate ]; then \
	# 	make nuke-region-vpc; \
	# else \
	# 	echo "Deleting network acl..."; for networkAclId in $(aws ec2 describe-network-acls --query 'NetworkAcls[].NetworkAclId'); do aws ec2 delete-network-acl --network-acl-id $networkAclId; done; \
	# 	cd ${VPC_PATH}; \
	# 	terragrunt destroy -auto-approve; \
	# 	rm ${VPC_PATH}/terraform.tfstate; \
	# fi
	make nuke-region-vpc;

nuke: ## Nuke all resources in all regions
	cloud-nuke aws;
nuke-region-exclude-vpc: ## Nuke within the user's region all resources excluding vpc, e.g. for repeating tests manually
	cloud-nuke aws --region ${AWS_REGION} --exclude-resource-type vpc --force;
nuke-region-vpc:
	cloud-nuke aws --region ${AWS_REGION} --resource-type vpc --force;
nuke-global:
	cloud-nuke aws --region global --force;

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
graph-modules-vpc: ## Generate the graph for the VPC
	make graph INFRAMAP_PATH=${ROOT_PATH}/modules/vpc
graph-modules-data-mongodb: ## Generate the graph for the MongoDB
	make graph INFRAMAP_PATH=${ROOT_PATH}/modules/data/mongodb
graph-modules-services-scraper-backend: ## Generate the graph for the scraper backend
	make graph INFRAMAP_PATH=${ROOT_PATH}/modules/services/scraper-backend
graph-modules-services-scraper-frontend: ## Generate the graph for the scraper frontend
	make graph INFRAMAP_PATH=${ROOT_PATH}/modules/services/scraper-frontend

rover-vpc:
	make rover-docker ROVER_MODULE=modules/vpc
rover-docker:
	sudo rover -workingDir ${ROOT_PATH}/${ROVER_MODULE} -tfVarsFile ${ROOT_PATH}/${ROVER_MODULE}/terraform_override.tfvars -genImage true
