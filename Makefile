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

# Github
GH_ORG=KookaS

# absolute path
ROOT_PATH=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
VPC_PATH=${ROOT_PATH}/modules/vpc

# silent all commands below
.SILENT:

fmt: ## Format all files
	terraform fmt -recursive

test: ## Setup the test environment, run the tests and clean the environment
	make clean; \
	make prepare; \
	# -p 1 flag to test each package sequentially; \
	cd ${ROOT_PATH}; \
	go test -timeout 30m -p 1 -v -cover ./...; \
	make clean;
test-clean-cache:
	go clean -testcache;

prepare: ## Setup the test environment
	make prepare-account; \
	make prepare-modules-data-mongodb; \
	make prepare-modules-vpc; \
	make prepare-modules-services-scraper-backend;
prepare-account:
	echo 'locals {' 							> 	${ROOT_PATH}/modules/account.hcl; \
	echo 'aws_account_region="${AWS_REGION}"' 	>> 	${ROOT_PATH}/modules/account.hcl; \
	echo 'aws_account_name="${AWS_PROFILE}"' 	>> 	${ROOT_PATH}/modules/account.hcl; \
	echo 'aws_account_id="${AWS_ID}"' 			>> 	${ROOT_PATH}/modules/account.hcl; \
	echo 'aws_access_key="${AWS_ACCESS_KEY}"' 	>> 	${ROOT_PATH}/modules/account.hcl; \
	echo 'aws_secret_key="${AWS_SECRET_KEY}"' 	>> 	${ROOT_PATH}/modules/account.hcl; \
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
prepare-modules-services-scraper-backend:
	make load-config MODULE_PATH=modules/services/scraper-backend-lb GH_PATH=https://raw.githubusercontent.com/${GH_ORG}/scraper-backend/production/config; \
	# make prepare-github \
	# 	GITHUB_REPO_ID=497233030 \
	# 	GITHUB_REPO_OWNER=KookaS \
	# 	GITHUB_REPO_NAME=scraper-backend \
	# 	GITHUB_ENV=KookaS \
	# 	GITHUB_SECRET_KEY=AWS_ACCESS_KEY \
	# 	GITHUB_SECRET_VALUE=${AWS_ACCESS_KEY}; \
	# make prepare-github \
	# 	GITHUB_REPO_ID=497233030 \
	# 	GITHUB_REPO_OWNER=KookaS \
	# 	GITHUB_REPO_NAME=scraper-backend \
	# 	GITHUB_ENV=KookaS \
	# 	GITHUB_SECRET_KEY=AWS_SECRET_KEY \
	# 	GITHUB_SECRET_VALUE=${AWS_SECRET_KEY}; \
	cd ${ROOT_PATH}/modules/services/scraper-backend-lb; \
	terragrunt init;
load-config:
	curl -H 'Authorization: token ${GITHUB_TOKEN}' -o ${MODULE_PATH}/config_override.yml ${GH_PATH}/config.yml; \
	curl -H 'Authorization: token ${GITHUB_TOKEN}' -o ${MODULE_PATH}/config_override.go ${GH_PATH}/config.go; \
	sed -i 's/package .*/package test/' ${MODULE_PATH}/config_override.go;	# add package name to go file
prepare-github:
	# gh api \
	# 	--method PUT \
	# 	-H "Accept: application/vnd.github+json" \
	# 	-f encrypted_value='${GITHUB_SECRET_VALUE}' \
	# 	-f key_id='$(shell gh api -H "Accept: application/vnd.github+json" /repos/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}/actions/secrets/public-key --jq .key_id)' \
	# 	/repositories/${GITHUB_REPO_ID}/environments/${GITHUB_ENV}/secrets/${GITHUB_SECRET_KEY}; \
	# curl -L \
	# 	-X PUT \
	# 	-H "Accept: application/vnd.github+json" \
	# 	-H "Authorization: Bearer ${GITHUB_TOKEN}"\
	# 	-H "X-GitHub-Api-Version: 2022-11-28" \
	# 	https://api.github.com/repositories/${GITHUB_REPO_ID}/environments/${GITHUB_ENV}/secrets/${GITHUB_SECRET_KEY} \
	# 	-d '{"encrypted_value":${GITHUB_SECRET_VALUE},"key_id":"$(shell gh api -H "Accept: application/vnd.github+json" /repos/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}/actions/secrets/public-key --jq .key_id)"}'

clean: ## Clean the test environment
	make nuke-region-exclude-vpc; \
	make clean-vpc; \

	echo "Deleting cloudwatch alarms..."; for alarmName in $(aws cloudwatch describe-alarms --query 'MetricAlarms[].AlarmName'); do aws cloudwatch delete-alarms --alarm-names $alarmName; done; \

	echo "Diregistring task definitions..."; for taskDefinition in $(aws ecs list-task-definitions --status ACTIVE --query 'taskDefinitionArns[]'); do aws ecs deregister-task-definition --task-definition $taskDefinition --query 'taskDefinition.taskDefinitionArn'; done; \

	# echo "Deleting task definitions..."; for taskDefinition in $(aws ecs list-task-definitions --status INACTIVE --query 'taskDefinitionArns[]'); do aws ecs delete-task-definitions --task-definition $taskDefinition --query 'taskDefinition.taskDefinitionArn'; done; \

	echo "Delete registries..."; for repositoryName in $(aws ecr describe-repositories --query 'repositories[].repositoryName'); do aws ecr delete-repository --repository-name $repositoryName --force --query 'repository.repositoryName'; done;

	echo "Deleteing state files..."; for filePath in $(find . -type f -name "*.tfstate"); do echo $filePath; rm $filePath; done; \
	echo "Deleteing override files..."; for filePath in $(find . -type f -name "*_override.*"); do echo $filePath; rm $filePath; done;

clean-old: ## Clean the test environment that is old
	make nuke-old-region-exclude-vpc; \
	make clean-old-vpc;
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
clean-old-vpc:
	make nuke-old-region-vpc;

OLD=4h
# nuke: ## Nuke all resources
# 	cloud-nuke aws;
# nuke-region: ## Nuke within the user's region all resources
# 	cloud-nuke aws --region ${AWS_REGION} --force;
nuke-region-exclude-vpc: ## Nuke within the user's region all resources excluding vpc, e.g. for repeating tests manually
	cloud-nuke aws --region ${AWS_REGION} --exclude-resource-type vpc --force;
nuke-region-vpc:
	cloud-nuke aws --region ${AWS_REGION} --resource-type vpc --force;
nuke-old-region-exclude-vpc:
	cloud-nuke aws --region ${AWS_REGION} --exclude-resource-type vpc --older-than $OLD --force;
nuke-old-region-vpc:
	cloud-nuke aws --region ${AWS_REGION} --resource-type vpc --older-than $OLD --force;

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
