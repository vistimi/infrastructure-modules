SHELL:=/bin/bash
.SILENT:
MAKEFLAGS += --no-print-directory
MAKEFLAGS += --warn-undefined-variables
.ONESHELL:

PATH_ABS_ROOT=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

PATH_AWS=module/aws
PATH_AWS_IAM=module/aws/iam

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
	}
	EOF

prepare-global-level:
	make -f Makefile_infra init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/module/_global/level

prepare-aws-iam-level:
	make -f Makefile_infra init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/${PATH_AWS_IAM}/level
prepare-aws-iam-group:
	make -f Makefile_infra init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_ROOT}/${PATH_AWS_IAM}/group


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