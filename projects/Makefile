SHELL:=/bin/bash
.SILENT:
MAKEFLAGS += --no-print-directory
MAKEFLAGS += --warn-undefined-variables
.ONESHELL:

PATH_ABS_ROOT=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
FILE_NAME=$(shell basename $(MAKEFILE_LIST))
INFRA_FILE_NAME=Makefile_infra

PATH_AWS_PROJECTS=module/aws/projects
PATH_TEST_AWS_PROJECTS=test/aws/projects

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
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} aws-auth AWS_PROFILE_NAME=${AWS_PROFILE_NAME} AWS_REGION_NAME=${AWS_REGION_NAME} AWS_ACCESS_KEY=${AWS_ACCESS_KEY} AWS_SECRET_KEY=${AWS_SECRET_KEY}
	aws configure list

test-clear: ## Clear the cache for the tests
	go clean -testcache

prepare-terragrunt:
	make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-account-aws ACCOUNT_PATH=${PATH_ABS_ROOT}/module/_global
	make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-account-aws ACCOUNT_PATH=${PATH_ABS_ROOT}/module/aws
prepare-account-aws:
	cat <<-EOF > ${ACCOUNT_PATH}/aws_account_override.hcl
	locals {
		aws_account_region="${AWS_REGION_NAME}"
		aws_account_name="${AWS_PROFILE_NAME}"
		aws_account_id="${AWS_ACCOUNT_ID}"
	}
	EOF

prepare-global-level:
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/module/_global/level

prepare-aws-scraper-labelstudio:
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/module/aws/projects/scraper/labelstudio

ORCHESTRATOR ?= ecs
prepare-aws-tryon-backend:
	$(call check_defined, ORCHESTRATOR)
	make -f ${PATH_ABS_ROOT}/../Makefile prepare-aws-microservice ORCHESTRATOR=${ORCHESTRATOR}
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/../module/aws/container/microservice

BRANCH_NAME ?= trunk
prepare-aws-scraper-backend:
	$(eval GIT_NAME=github.com)
	$(eval ORGANIZATION_NAME=dresspeng)
	$(eval PROJECT_NAME=scraper)
	$(eval SERVICE_NAME=backend)
	$(eval COMMON_NAME="")
	$(eval CLOUD_HOST=aws)
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} gh-load-folder \
		TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/${PATH_TEST_AWS_PROJECTS}/${PROJECT_NAME}/${SERVICE_NAME} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${PROJECT_NAME}-${SERVICE_NAME} \
		BRANCH_NAME=${BRANCH_NAME} \
		REPOSITORY_CONFIG_PATH_FOLDER=config
	make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-scraper-backend-env \
		REPOSITORY_CONFIG_PATH=${PATH_ABS_ROOT}/${PATH_TEST_AWS_PROJECTS}/${PROJECT_NAME}/${SERVICE_NAME} \
		ENV_FOLDER_PATH=${PATH_ABS_ROOT}/${PATH_AWS_PROJECTS}/${PROJECT_NAME}/${SERVICE_NAME} \
		COMMON_NAME=${COMMON_NAME} \
		CLOUD_HOST=${CLOUD_HOST}
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/${PATH_AWS_PROJECTS}/${PROJECT_NAME}/${SERVICE_NAME}
make prepare-scraper-backend-env:
	$(eval MAKEFILE_OVERRIDE=$(shell find ${REPOSITORY_CONFIG_PATH} -type f -name "*Makefile*"))
	make -f ${MAKEFILE_OVERRIDE} prepare \
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
prepare-aws-scraper-frontend:
	$(eval GIT_NAME=github.com)
	$(eval ORGANIZATION_NAME=dresspeng)
	$(eval PROJECT_NAME=scraper)
	$(eval SERVICE_NAME=frontend)
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} gh-load-folder \
		TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/${PATH_TEST_AWS_PROJECTS}/${PROJECT_NAME}/${SERVICE_NAME} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${PROJECT_NAME}-${SERVICE_NAME} \
		BRANCH_NAME=${BRANCH_NAME} \
		REPOSITORY_CONFIG_PATH_FOLDER=config
	make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-scraper-frontend-env \
		REPOSITORY_CONFIG_PATH=${PATH_ABS_ROOT}/${PATH_TEST_AWS_PROJECTS}/${PROJECT_NAME}/${SERVICE_NAME} \
		ENV_FOLDER_PATH=${PATH_ABS_ROOT}/${PATH_AWS_PROJECTS}/${PROJECT_NAME}/${SERVICE_NAME}
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/${PATH_AWS_PROJECTS}/${PROJECT_NAME}/${SERVICE_NAME}
prepare-scraper-frontend-env:
	echo ${REPOSITORY_CONFIG_PATH}
	$(eval MAKEFILE_OVERRIDE=$(shell find ${REPOSITORY_CONFIG_PATH} -type f -name "*Makefile*"))
	make -f ${MAKEFILE_OVERRIDE} prepare \
		ENV_FOLDER_PATH=${ENV_FOLDER_PATH} \
		NEXT_PUBLIC_API_URL="http://not-needed.com" \
		PORT=$(shell yq eval '.port' ${REPOSITORY_CONFIG_PATH}/config_${OVERRIDE_EXTENSION}.yml)

clean: ## Clean the test environment
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} nuke-region
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} nuke-vpc
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} nuke-global

	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} clean-task-definition
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} clean-elb
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} clean-ecs

	make clean-local

clean-local: ## Clean the local files and folders
	echo "Delete state files..."; for filePath in $(shell find . -type f -name "*.tfstate"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete state backup files..."; for folderPath in $(shell find . -type f -name "terraform.tfstate.backup"); do echo $$folderPath; rm -Rf $$folderPath; done; \
	echo "Delete override files..."; for filePath in $(shell find . -type f -name "*_override.*"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete lock files..."; for folderPath in $(shell find . -type f -name ".terraform.lock.hcl"); do echo $$folderPath; rm -Rf $$folderPath; done;

	echo "Delete temp folder..."; for folderPath in $(shell find . -type d -name ".terraform"); do echo $$folderPath; rm -Rf $$folderPath; done;