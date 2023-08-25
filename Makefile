SHELL:=/bin/bash
.SILENT:
MAKEFLAGS += --no-print-directory
MAKEFLAGS += --warn-undefined-variables
.ONESHELL:

PATH_ABS_ROOT=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
FILE_NAME=$(shell basename $(MAKEFILE_LIST))
INFRA_FILE_NAME=Makefile_infra

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
	make -f ${PATH_ABS_ROOT}/${FILE_NAME} prepare-account-aws ACCOUNT_PATH=${PATH_ABS_ROOT}/module/aws
prepare-account-aws:
	cat <<-EOF > ${ACCOUNT_PATH}/aws_account_override.hcl
	locals {
		aws_account_region="${AWS_REGION_NAME}"
		aws_account_name="${AWS_PROFILE_NAME}"
		aws_account_id="${AWS_ACCOUNT_ID}"
	}
	EOF

prepare-aws-microservice:
	$(call check_defined, ORCHESTRATOR)
	cat <<-EOF > ${PATH_ABS_ROOT}/module/aws/container/microservice/microservice_override.hcl
	locals {
		orchestrator="${ORCHESTRATOR}"
	}
	EOF
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/module/aws/container/microservice

prepare-aws-iam-level:
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/module/aws/iam/level
prepare-aws-iam-group:
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/module/aws/iam/group

prepare-github-variables:
	make -f ${PATH_ABS_ROOT}/${INFRA_FILE_NAME} init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/module/github/variables

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