SHELL:=/bin/bash
.SILENT:
MAKEFLAGS += --no-print-directory
MAKEFLAGS += --warn-undefined-variables
.ONESHELL:

PATH_ABS_ROOT=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

PATH_AWS=module/aws
PATH_AWS_MICROSERVICE=${PATH_AWS}/microservice
PATH_AWS_IAM=${PATH_AWS}/iam
PATH_AWS_ECR=${PATH_AWS}/container/ecr

PATH_TEST_AWS_MICROSERVICE=test/aws/microservice

OVERRIDE_EXTENSION=override
export OVERRIDE_EXTENSION
export AWS_REGION_NAME AWS_PROFILE_NAME AWS_ACCOUNT_ID AWS_ACCESS_KEY AWS_SECRET_KEY

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

fmt: ## Format all files
	terraform fmt -recursive

aws-auth:
	make -f Makefile_infra aws-auth AWS_PROFILE_NAME=${AWS_PROFILE_NAME} AWS_REGION_NAME=${AWS_REGION_NAME} AWS_ACCESS_KEY=${AWS_ACCESS_KEY} AWS_SECRET_KEY=${AWS_SECRET_KEY}
	aws configure list

test: ## Setup the test environment, run the tests and clean the environment
	make test-prepare; \
	# # p1 will not mix the logs when multiple tests are used
	# go test -timeout 30m -p 1 -v -cover ./...; \
	make clean;
test-clear: ## Clear the cache for the tests
	go clean -testcache

prepare-terragrunt:
	make prepare-account-aws ACCOUNT_PATH=${PATH_ABS_ROOT}/${PATH_AWS}
	make prepare-account-aws ACCOUNT_PATH=${PATH_ABS_ROOT}/module/_global
prepare-account-aws:
	cat <<-EOF > ${ACCOUNT_PATH}/aws_account_override.hcl
	locals {
		aws_account_region="${AWS_REGION_NAME}"
		aws_account_name="${AWS_PROFILE_NAME}"
		aws_account_id="${AWS_ACCOUNT_ID}"
		repositories_aws_account_region="${REPOSITORIES_AWS_REGION_NAME}"
		repositories_aws_account_name="${REPOSITORIES_AWS_PROFILE_NAME}"
		repositories_aws_account_id="${REPOSITORIES_AWS_ACCOUNT_ID}"
	}
	EOF

prepare-global-level:
	make -f Makefile_infra init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/module/_global/level

prepare-aws-iam-level:
	make -f Makefile_infra init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/${PATH_AWS_IAM}/level
prepare-aws-iam-group:
	make -f Makefile_infra init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/${PATH_AWS_IAM}/group

BRANCH_NAME ?= trunk
prepare-aws-microservice-scraper-backend:
	$(eval GIT_NAME=github.com)
	$(eval ORGANIZATION_NAME=KookaS)
	$(eval PROJECT_NAME=scraper)
	$(eval SERVICE_NAME=backend)
	$(eval REPOSITORY_NAME=${PROJECT_NAME}-${SERVICE_NAME})
	$(eval OUTPUT_FOLDER=${PATH_TEST_AWS_MICROSERVICE}/${REPOSITORY_NAME})
	$(eval COMMON_NAME="")
	$(eval CLOUD_HOST=aws)
	make -f Makefile_infra gh-load-folder \
		TERRAGRUNT_CONFIG_PATH=${OUTPUT_FOLDER} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		BRANCH_NAME=${BRANCH_NAME} \
		REPOSITORY_CONFIG_PATH_FOLDER=config
	make prepare-microservice-scraper-backend-env \
		REPOSITORY_CONFIG_PATH=${OUTPUT_FOLDER} \
		ENV_FOLDER_PATH=${PATH_ABS_ROOT}/${PATH_AWS_MICROSERVICE}/${REPOSITORY_NAME} \
		COMMON_NAME=${COMMON_NAME} \
		CLOUD_HOST=${CLOUD_HOST}
	make -f Makefile_infra init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/${PATH_AWS_MICROSERVICE}/${REPOSITORY_NAME}
make prepare-microservice-scraper-backend-env:
	$(eval MAKEFILE=$(shell find ${REPOSITORY_CONFIG_PATH} -type f -name "*Makefile*"))
	make -f ${MAKEFILE} prepare \
		ENV_FOLDER_PATH=${ENV_FOLDER_PATH} \
		CONFIG_FOLDER_PATH=${REPOSITORY_CONFIG_PATH} \
		COMMON_NAME=${COMMON_NAME} \
		CLOUD_HOST=${CLOUD_HOST} \
		FLICKR_PRIVATE_KEY=123 \
		FLICKR_PUBLIC_KEY=123 \
		UNSPLASH_PRIVATE_KEY=123 \
		UNSPLASH_PUBLIC_KEY=123 \
		PEXELS_PUBLIC_KEY=123 \
		PACKAGE_NAME=microservice_scraper_backend_test \

BRANCH_NAME ?= trunk
prepare-aws-microservice-scraper-frontend:
	$(eval GIT_NAME=github.com)
	$(eval ORGANIZATION_NAME=KookaS)
	$(eval PROJECT_NAME=scraper)
	$(eval SERVICE_NAME=frontend)
	$(eval REPOSITORY_NAME=${PROJECT_NAME}-${SERVICE_NAME})
	$(eval OUTPUT_FOLDER=${PATH_TEST_AWS_MICROSERVICE}/${REPOSITORY_NAME})
	make -f Makefile_infra gh-load-folder \
		TERRAGRUNT_CONFIG_PATH=${OUTPUT_FOLDER} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		BRANCH_NAME=${BRANCH_NAME} \
		REPOSITORY_CONFIG_PATH_FOLDER=config
	make prepare-microservice-scraper-frontend-env \
		REPOSITORY_CONFIG_PATH=${OUTPUT_FOLDER} \
		ENV_FOLDER_PATH=${PATH_ABS_ROOT}/${PATH_AWS_MICROSERVICE}/${REPOSITORY_NAME}
	make -f Makefile_infra init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/${PATH_AWS_MICROSERVICE}/${REPOSITORY_NAME}
prepare-microservice-scraper-frontend-env:
	$(eval MAKEFILE=$(shell find ${REPOSITORY_CONFIG_PATH} -type f -name "*Makefile*"))
	make -f ${MAKEFILE} prepare \
		ENV_FOLDER_PATH=${ENV_FOLDER_PATH} \
		NEXT_PUBLIC_API_URL="http://not-needed.com" \
		PORT=$(shell yq eval '.port' ${REPOSITORY_CONFIG_PATH}/config_${OVERRIDE_EXTENSION}.yml)

clean: ## Clean the test environment
	make -f Makefile_infra nuke-region
	make -f Makefile_infra nuke-vpc
	make -f Makefile_infra nuke-global

	make -f Makefile_infra clean-task-definition
	make -f Makefile_infra clean-elb
	make -f Makefile_infra clean-ecs

	make clean-local

clean-local: ## Clean the local files and folders
	echo "Delete state files..."; for filePath in $(shell find . -type f -name "*.tfstate"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete state backup files..."; for folderPath in $(shell find . -type f -name "terraform.tfstate.backup"); do echo $$folderPath; rm -Rf $$folderPath; done; \
	echo "Delete override files..."; for filePath in $(shell find . -type f -name "*_override.*"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete lock files..."; for folderPath in $(shell find . -type f -name ".terraform.lock.hcl"); do echo $$folderPath; rm -Rf $$folderPath; done;

	echo "Delete temp folder..."; for folderPath in $(shell find . -type d -name ".terraform"); do echo $$folderPath; rm -Rf $$folderPath; done;